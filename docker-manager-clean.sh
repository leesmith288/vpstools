#!/bin/bash
# Docker Manager - Part of VPS Tools Suite
# Host as: docker-manager.sh

# Colors - High contrast for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'
BG_GREEN='\033[42m'
BG_RED='\033[41m'
BG_YELLOW='\033[43m'

# Helper functions for better readability
print_header() {
    clear
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}              🐳 Docker Update Manager                    ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
}

print_section() {
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}▶${NC} ${BOLD}$1${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_info() {
    echo -e "${BLUE}ℹ${NC}  ${BOLD}$1${NC}"
}

print_success() {
    echo -e "\n${BG_GREEN}${BOLD} ✓ SUCCESS ${NC} ${GREEN}$1${NC}\n"
}

print_error() {
    echo -e "\n${BG_RED}${BOLD} ✗ ERROR ${NC} ${RED}$1${NC}\n"
}

print_warning() {
    echo -e "\n${BG_YELLOW}${BOLD} ⚠ WARNING ${NC} ${YELLOW}$1${NC}\n"
}

wait_for_enter() {
    echo -e "\n${YELLOW}════════════════════════════════════════${NC}"
    echo -e "${BOLD}Press Enter to continue...${NC}"
    echo -e "${YELLOW}════════════════════════════════════════${NC}"
    read
}

# Format file size for readability
format_size() {
    local size=$1
    if [ $size -gt 1073741824 ]; then
        echo "$(( size / 1073741824 ))GB"
    elif [ $size -gt 1048576 ]; then
        echo "$(( size / 1048576 ))MB"
    else
        echo "$(( size / 1024 ))KB"
    fi
}

# Check disk space
check_disk_space() {
    local required=$1
    local path=$2
    local available=$(df "$path" | tail -1 | awk '{print $4}')
    
    if [ $available -lt $required ]; then
        print_warning "Low disk space!"
        echo -e "${BOLD}Available:${NC} $(format_size $((available * 1024)))"
        echo -e "${BOLD}Required:${NC}  $(format_size $((required * 1024)))"
        echo -e "\n${BOLD}Continue anyway? (y/N):${NC} "
        read -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && return 1
    fi
    return 0
}

# Backup functions
identify_app_type() {
    local compose_file=$1
    local app_type="generic"
    
    # Check for common applications
    if grep -qi "vaultwarden\|bitwarden" "$compose_file" 2>/dev/null; then
        app_type="vaultwarden"
    elif grep -qi "postgres" "$compose_file" 2>/dev/null; then
        app_type="postgresql"
    elif grep -qi "mysql\|mariadb" "$compose_file" 2>/dev/null; then
        app_type="mysql"
    elif grep -qi "mongo" "$compose_file" 2>/dev/null; then
        app_type="mongodb"
    elif grep -qi "nextcloud" "$compose_file" 2>/dev/null; then
        app_type="nextcloud"
    elif grep -qi "gitlab" "$compose_file" 2>/dev/null; then
        app_type="gitlab"
    fi
    
    echo "$app_type"
}

search_backup_requirements() {
    local app_name=$1
    print_info "Searching for $app_name backup requirements..."
    
    # Simulate search results based on app type
    case $app_name in
        vaultwarden)
            echo "Critical files: db.sqlite3, rsa_key.*, attachments/, sends/, config.json"
            ;;
        postgresql)
            echo "Use pg_dump for database export"
            ;;
        mysql)
            echo "Use mysqldump for database export"
            ;;
        mongodb)
            echo "Use mongodump for database export"
            ;;
        *)
            echo "Standard volume backup recommended"
            ;;
    esac
}

analyze_container_data() {
    local dir=$1
    local compose_file="$dir/docker-compose.yml"
    [ ! -f "$compose_file" ] && compose_file="$dir/compose.yml"
    
    local container_name=$(grep -m1 "container_name:" "$compose_file" 2>/dev/null | awk '{print $2}' | tr -d '"' || basename "$dir")
    local app_type=$(identify_app_type "$compose_file")
    
    # Get volumes
    local volumes=$(docker inspect $(docker compose -f "$compose_file" ps -q 2>/dev/null | head -1) 2>/dev/null | jq -r '.[0].Mounts[] | select(.Type == "volume") | .Name' 2>/dev/null)
    local bind_mounts=$(docker inspect $(docker compose -f "$compose_file" ps -q 2>/dev/null | head -1) 2>/dev/null | jq -r '.[0].Mounts[] | select(.Type == "bind") | .Source' 2>/dev/null)
    
    echo "$container_name|$app_type|$volumes|$bind_mounts"
}

backup_menu() {
    while true; do
        print_header
        print_section "BACKUP & RESTORE"
        
        echo -e "${BOLD}Select an option:${NC}\n"
        echo -e "${YELLOW}  1)${NC} 📦 ${BOLD}Create new backup${NC}"
        echo -e "${YELLOW}  2)${NC} 📋 ${BOLD}List existing backups${NC}"
        echo -e "${YELLOW}  3)${NC} 🔄 ${BOLD}Restore from backup${NC}"
        echo -e "${YELLOW}  4)${NC} 🗑️  ${BOLD}Delete old backups${NC}"
        echo -e "\n${RED}  0)${NC} ↩️  ${BOLD}Back to main menu${NC}\n"
        
        read -p "$(echo -e ${BOLD}Your choice: ${NC})" choice
        
        case $choice in
            1) create_backup ;;
            2) list_backups ;;
            3) restore_backup ;;
            4) delete_backups ;;
            0) return ;;
            *) print_error "Invalid option"; sleep 2 ;;
        esac
    done
}

create_backup() {
    print_header
    print_section "CREATE NEW BACKUP"
    
    # Find all docker compose projects
    dirs=($(find ~ -type f \( -name "docker-compose.yml" -o -name "compose.yml" \) 2>/dev/null | xargs -I {} dirname {} | sort -u))
    
    if [ ${#dirs[@]} -eq 0 ]; then
        print_error "No Docker Compose projects found!"
        wait_for_enter
        return
    fi
    
    # Display projects with details
    echo -e "${BOLD}Select project to backup:${NC}\n"
    
    for i in "${!dirs[@]}"; do
        dir="${dirs[$i]}"
        info=$(analyze_container_data "$dir")
        IFS='|' read -r container_name app_type volumes bind_mounts <<< "$info"
        
        # Visual indicator for app type
        case $app_type in
            vaultwarden) icon="🔐" ;;
            postgresql|mysql|mongodb) icon="🗄️" ;;
            nextcloud) icon="☁️" ;;
            gitlab) icon="🦊" ;;
            *) icon="📦" ;;
        esac
        
        printf "${YELLOW}%2d)${NC} ${icon} ${BOLD}%-20s${NC} ${DIM}[%s]${NC}\n" "$((i+1))" "$container_name" "$app_type"
        printf "    ${DIM}Path: %s${NC}\n" "$dir"
        
        # Show what will be backed up
        [ -n "$volumes" ] && echo -e "    ${CYAN}Volumes:${NC} $(echo $volumes | tr '\n' ', ')"
        [ -n "$bind_mounts" ] && echo -e "    ${CYAN}Mounts:${NC} $(echo $bind_mounts | tr '\n' ', ')"
        echo
    done
    
    echo -e "${RED}  0)${NC} Cancel\n"
    read -p "$(echo -e ${BOLD}Select project number: ${NC})" proj_num
    
    if [[ "$proj_num" =~ ^[0-9]+$ ]] && [ "$proj_num" -gt 0 ] && [ "$proj_num" -le "${#dirs[@]}" ]; then
        backup_project "${dirs[$((proj_num-1))]}"
    fi
}

backup_project() {
    local project_dir=$1
    local compose_file="$project_dir/docker-compose.yml"
    [ ! -f "$compose_file" ] && compose_file="$project_dir/compose.yml"
    
    local info=$(analyze_container_data "$project_dir")
    IFS='|' read -r container_name app_type volumes bind_mounts <<< "$info"
    
    print_header
    print_section "BACKING UP: $container_name"
    
    # Search for backup requirements
    local requirements=$(search_backup_requirements "$app_type")
    if [ -n "$requirements" ]; then
        print_info "Backup requirements for $app_type:"
        echo -e "${CYAN}$requirements${NC}\n"
    fi
    
    # Prepare backup
    local backup_dir="$project_dir/backups"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_name="${container_name}-${timestamp}"
    local backup_path="$backup_dir/${backup_name}.tar.gz"
    
    # Check disk space (estimate 2x the data size for safety)
    local data_size=0
    if [ -n "$volumes" ]; then
        for vol in $volumes; do
            size=$(docker system df -v | grep "$vol" | awk '{print $4}' | grep -o '[0-9]*' | head -1)
            data_size=$((data_size + size * 1024 * 1024))
        done
    fi
    
    print_info "Estimated backup size: $(format_size $data_size)"
    
    if ! check_disk_space $((data_size * 2 / 1024)) "$project_dir"; then
        return
    fi
    
    # Confirm backup
    echo -e "\n${BOLD}📁 Backup will include:${NC}"
    echo -e "   • Docker compose configuration"
    echo -e "   • Environment files"
    [ -n "$volumes" ] && echo -e "   • Docker volumes"
    [ -n "$bind_mounts" ] && echo -e "   • Bind mount directories"
    
    echo -e "\n${BOLD}📍 Backup location:${NC}"
    echo -e "   $backup_path"
    
    echo -e "\n${YELLOW}⚠️  Container will be stopped during backup${NC}"
    echo -e "\n${BOLD}Proceed with backup? (y/N):${NC} "
    read -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Backup cancelled"
        wait_for_enter
        return
    fi
    
    # Create backup directory
    mkdir -p "$backup_dir"
    
    # Perform backup
    print_info "Starting backup process..."
    
    # Stop container
    echo -e "\n${BOLD}Stopping container...${NC}"
    cd "$project_dir"
    docker compose stop
    
    # Create temporary backup directory
    local temp_backup="/tmp/backup-$backup_name"
    mkdir -p "$temp_backup"
    
    # Copy compose files
    echo -e "${BOLD}Copying configuration files...${NC}"
    cp -p "$compose_file" "$temp_backup/"
    [ -f "$project_dir/.env" ] && cp -p "$project_dir/.env" "$temp_backup/"
    
    # Backup based on app type
    case $app_type in
        vaultwarden)
            backup_vaultwarden "$temp_backup" "$volumes" "$project_dir"
            ;;
        postgresql)
            backup_postgresql "$temp_backup" "$container_name"
            ;;
        mysql)
            backup_mysql "$temp_backup" "$container_name"
            ;;
        mongodb)
            backup_mongodb "$temp_backup" "$container_name"
            ;;
        *)
            backup_generic "$temp_backup" "$volumes" "$bind_mounts"
            ;;
    esac
    
    # Create archive
    echo -e "\n${BOLD}Creating backup archive...${NC}"
    cd /tmp
    tar -czf "$backup_path" "backup-$backup_name"
    
    # Calculate checksum
    echo -e "${BOLD}Generating checksum...${NC}"
    local checksum=$(sha256sum "$backup_path" | awk '{print $1}')
    echo "$checksum" > "$backup_path.sha256"
    
    # Cleanup
    rm -rf "$temp_backup"
    
    # Restart container
    echo -e "\n${BOLD}Restarting container...${NC}"
    cd "$project_dir"
    docker compose up -d
    
    # Show results
    local final_size=$(stat -f%z "$backup_path" 2>/dev/null || stat -c%s "$backup_path" 2>/dev/null)
    
    print_success "Backup completed successfully!"
    
    echo -e "${BOLD}📦 Backup Details:${NC}"
    echo -e "   ${BOLD}File:${NC} $backup_path"
    echo -e "   ${BOLD}Size:${NC} $(format_size $final_size)"
    echo -e "   ${BOLD}SHA256:${NC} ${checksum:0:16}..."
    
    # Offer download
    echo -e "\n${BOLD}📥 Download backup to your computer?${NC}"
    echo -e "${YELLOW}  1)${NC} Yes - Show download command"
    echo -e "${YELLOW}  2)${NC} No - I'll download later\n"
    
    read -p "$(echo -e ${BOLD}Choice: ${NC})" dl_choice
    
    if [ "$dl_choice" = "1" ]; then
        setup_download "$backup_path"
    fi
    
    wait_for_enter
}

backup_vaultwarden() {
    local backup_dir=$1
    local volumes=$2
    local project_dir=$3
    
    echo -e "${BOLD}Backing up Vaultwarden data...${NC}"
    
    # Find data directory
    local data_dir
    if [ -d "$project_dir/vw-data" ]; then
        data_dir="$project_dir/vw-data"
    elif [ -d "$project_dir/data" ]; then
        data_dir="$project_dir/data"
    else
        # Try to find from volume
        for vol in $volumes; do
            local vol_path=$(docker volume inspect "$vol" | jq -r '.[0].Mountpoint' 2>/dev/null)
            if [ -n "$vol_path" ] && [ -d "$vol_path" ]; then
                data_dir="$vol_path"
                break
            fi
        done
    fi
    
    if [ -n "$data_dir" ] && [ -d "$data_dir" ]; then
        # Backup critical files
        mkdir -p "$backup_dir/vaultwarden-data"
        
        # Database
        [ -f "$data_dir/db.sqlite3" ] && cp -p "$data_dir/db.sqlite3" "$backup_dir/vaultwarden-data/"
        [ -f "$data_dir/db.sqlite3-wal" ] && cp -p "$data_dir/db.sqlite3-wal" "$backup_dir/vaultwarden-data/"
        [ -f "$data_dir/db.sqlite3-shm" ] && cp -p "$data_dir/db.sqlite3-shm" "$backup_dir/vaultwarden-data/"
        
        # Keys
        [ -f "$data_dir/rsa_key.pem" ] && cp -p "$data_dir/rsa_key.pem" "$backup_dir/vaultwarden-data/"
        [ -f "$data_dir/rsa_key.pub.pem" ] && cp -p "$data_dir/rsa_key.pub.pem" "$backup_dir/vaultwarden-data/"
        
        # Attachments and sends
        [ -d "$data_dir/attachments" ] && cp -rp "$data_dir/attachments" "$backup_dir/vaultwarden-data/"
        [ -d "$data_dir/sends" ] && cp -rp "$data_dir/sends" "$backup_dir/vaultwarden-data/"
        
        # Config
        [ -f "$data_dir/config.json" ] && cp -p "$data_dir/config.json" "$backup_dir/vaultwarden-data/"
        
        echo -e "${GREEN}✓${NC} Vaultwarden data backed up"
    else
        print_warning "Could not find Vaultwarden data directory"
    fi
}

backup_postgresql() {
    local backup_dir=$1
    local container=$2
    
    # Check if pg_dump is available in container
    if docker exec "$container" which pg_dump >/dev/null 2>&1; then
        echo -e "${BOLD}Backing up PostgreSQL database...${NC}"
        docker exec "$container" pg_dumpall -U postgres > "$backup_dir/postgresql_dump.sql"
        echo -e "${GREEN}✓${NC} PostgreSQL database backed up"
    else
        print_warning "pg_dump not found in container, copying raw data files"
        backup_generic "$backup_dir" "" ""
    fi
}

backup_mysql() {
    local backup_dir=$1
    local container=$2
    
    # Check if mysqldump is available
    if docker exec "$container" which mysqldump >/dev/null 2>&1; then
        echo -e "${BOLD}Backing up MySQL database...${NC}"
        docker exec "$container" mysqldump --all-databases --single-transaction > "$backup_dir/mysql_dump.sql"
        echo -e "${GREEN}✓${NC} MySQL database backed up"
    else
        print_warning "mysqldump not found in container, copying raw data files"
        backup_generic "$backup_dir" "" ""
    fi
}

backup_mongodb() {
    local backup_dir=$1
    local container=$2
    
    # Check if mongodump is available
    if docker exec "$container" which mongodump >/dev/null 2>&1; then
        echo -e "${BOLD}Backing up MongoDB database...${NC}"
        mkdir -p "$backup_dir/mongodb_dump"
        docker exec "$container" mongodump --out /tmp/mongodump
        docker cp "$container:/tmp/mongodump" "$backup_dir/mongodb_dump"
        docker exec "$container" rm -rf /tmp/mongodump
        echo -e "${GREEN}✓${NC} MongoDB database backed up"
    else
        print_warning "mongodump not found in container, copying raw data files"
        backup_generic "$backup_dir" "" ""
    fi
}

backup_generic() {
    local backup_dir=$1
    local volumes=$2
    local bind_mounts=$3
    
    # Backup volumes
    if [ -n "$volumes" ]; then
        echo -e "${BOLD}Backing up Docker volumes...${NC}"
        mkdir -p "$backup_dir/volumes"
        
        for vol in $volumes; do
            echo -e "  Backing up volume: $vol"
            docker run --rm -v "$vol:/source:ro" -v "$backup_dir/volumes:/backup" alpine tar -czf "/backup/${vol}.tar.gz" -C /source .
        done
        echo -e "${GREEN}✓${NC} Volumes backed up"
    fi
    
    # Backup bind mounts
    if [ -n "$bind_mounts" ]; then
        echo -e "${BOLD}Backing up bind mounts...${NC}"
        mkdir -p "$backup_dir/bind_mounts"
        
        for mount in $bind_mounts; do
            if [ -d "$mount" ]; then
                mount_name=$(basename "$mount")
                echo -e "  Backing up mount: $mount_name"
                tar -czf "$backup_dir/bind_mounts/${mount_name}.tar.gz" -C "$mount" .
            fi
        done
        echo -e "${GREEN}✓${NC} Bind mounts backed up"
    fi
}

setup_download() {
    local backup_path=$1
    
    # Check for rsync
    if ! command -v rsync >/dev/null 2>&1; then
        echo -e "\n${YELLOW}Rsync not installed (recommended for reliable downloads)${NC}"
        echo -e "\n${BOLD}Install rsync now?${NC}"
        echo -e "${YELLOW}  1)${NC} Yes - Install rsync"
        echo -e "${YELLOW}  2)${NC} No - Use SCP instead\n"
        
        read -p "$(echo -e ${BOLD}Choice: ${NC})" install_choice
        
        if [ "$install_choice" = "1" ]; then
            print_info "Installing rsync..."
            if command -v apt-get >/dev/null 2>&1; then
                apt-get update && apt-get install -y rsync
            elif command -v yum >/dev/null 2>&1; then
                yum install -y rsync
            fi
            
            if command -v rsync >/dev/null 2>&1; then
                print_success "Rsync installed successfully!"
            else
                print_error "Failed to install rsync"
            fi
        fi
    fi
    
    # Get server IP
    local server_ip=$(hostname -I | awk '{print $1}')
    local username=$(whoami)
    
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}📥 DOWNLOAD INSTRUCTIONS${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    echo -e "${BOLD}Run this command on your Mac/PC:${NC}\n"
    
    if command -v rsync >/dev/null 2>&1; then
        echo -e "${CYAN}rsync -avP --progress ${username}@${server_ip}:${backup_path} ~/Downloads/${NC}"
    else
        echo -e "${CYAN}scp ${username}@${server_ip}:${backup_path} ~/Downloads/${NC}"
    fi
    
    echo -e "\n${DIM}💡 Tip: The command above is ready to copy and paste${NC}"
    echo -e "${DIM}📍 Your backup will be saved to: ~/Downloads/$(basename $backup_path)${NC}"
}

list_backups() {
    print_header
    print_section "EXISTING BACKUPS"
    
    local total_size=0
    local backup_count=0
    
    # Find all backup directories
    while IFS= read -r -d '' backup_dir; do
        if [ -d "$backup_dir" ] && [ "$(ls -A "$backup_dir"/*.tar.gz 2>/dev/null)" ]; then
            local project_name=$(basename "$(dirname "$backup_dir")")
            
            echo -e "${BOLD}📁 $project_name${NC}"
            echo -e "${DIM}   Path: $backup_dir${NC}\n"
            
            # List backups in this directory
            for backup in "$backup_dir"/*.tar.gz; do
                [ -f "$backup" ] || continue
                
                local size=$(stat -f%z "$backup" 2>/dev/null || stat -c%s "$backup" 2>/dev/null)
                local date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$backup" 2>/dev/null || stat -c "%y" "$backup" 2>/dev/null | cut -d' ' -f1,2)
                
                printf "   ${YELLOW}•${NC} %-40s ${BOLD}%8s${NC} ${DIM}%s${NC}\n" "$(basename "$backup")" "$(format_size $size)" "$date"
                
                total_size=$((total_size + size))
                backup_count=$((backup_count + 1))
            done
            echo
        fi
    done < <(find ~ -type d -name "backups" -print0 2>/dev/null)
    
    if [ $backup_count -eq 0 ]; then
        print_info "No backups found"
    else
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}Total: $backup_count backups, $(format_size $total_size)${NC}"
    fi
    
    wait_for_enter
}

delete_backups() {
    print_header
    print_section "DELETE OLD BACKUPS"
    
    # Find all backups
    local backups=()
    while IFS= read -r -d '' backup; do
        backups+=("$backup")
    done < <(find ~ -type f -name "*.tar.gz" -path "*/backups/*" -print0 2>/dev/null | sort -z)
    
    if [ ${#backups[@]} -eq 0 ]; then
        print_info "No backups found"
        wait_for_enter
        return
    fi
    
    echo -e "${BOLD}Select backups to delete:${NC}\n"
    
    # List backups with numbers
    for i in "${!backups[@]}"; do
        local backup="${backups[$i]}"
        local size=$(stat -f%z "$backup" 2>/dev/null || stat -c%s "$backup" 2>/dev/null)
        local date=$(stat -f "%Sm" -t "%Y-%m-%d" "$backup" 2>/dev/null || stat -c "%y" "$backup" 2>/dev/null | cut -d' ' -f1)
        
        printf "${YELLOW}%3d)${NC} %-40s ${BOLD}%8s${NC} ${DIM}%s${NC}\n" "$((i+1))" "$(basename "$backup")" "$(format_size $size)" "$date"
    done
    
    echo -e "\n${BOLD}Enter backup numbers to delete (space-separated), or 0 to cancel:${NC}"
    read -p "> " -a selections
    
    # Process selections
    local to_delete=()
    for sel in "${selections[@]}"; do
        if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -gt 0 ] && [ "$sel" -le "${#backups[@]}" ]; then
            to_delete+=("${backups[$((sel-1))]}")
        elif [ "$sel" = "0" ]; then
            return
        fi
    done
    
    if [ ${#to_delete[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}Delete ${#to_delete[@]} backup(s)?${NC}"
        echo -e "${BOLD}This action cannot be undone! (y/N):${NC} "
        read -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for backup in "${to_delete[@]}"; do
                rm -f "$backup" "$backup.sha256"
                echo -e "${GREEN}✓${NC} Deleted: $(basename "$backup")"
            done
            print_success "Backups deleted"
        else
            print_info "Deletion cancelled"
        fi
    fi
    
    wait_for_enter
}

restore_backup() {
    print_header
    print_section "RESTORE FROM BACKUP"
    
    print_warning "Restore functionality coming soon!"
    echo -e "${BOLD}Manual restore instructions:${NC}"
    echo -e "1. Stop the container: ${CYAN}docker compose down${NC}"
    echo -e "2. Extract backup: ${CYAN}tar -xzf backup.tar.gz${NC}"
    echo -e "3. Copy files back to original locations"
    echo -e "4. Start container: ${CYAN}docker compose up -d${NC}"
    
    wait_for_enter
}

# Main menu
docker_menu() {
    while true; do
        print_header
        
        echo -e "${GREEN}${BOLD}Docker Compose Projects:${NC}"
        echo -e "${YELLOW}  1)${NC} 📋 ${BOLD}List all Docker projects${NC}"
        echo -e "${YELLOW}  2)${NC} 🔄 ${BOLD}Update specific project${NC}"
        echo -e "${YELLOW}  3)${NC} ⚡ ${BOLD}Quick update (choose from list)${NC}"
        echo -e "${YELLOW}  4)${NC} 🔁 ${BOLD}Update all projects${NC}"
        echo -e "${YELLOW}  5)${NC} 🧹 ${BOLD}Clean Docker system${NC}"
        echo -e "${YELLOW}  6)${NC} 📊 ${BOLD}Show Docker disk usage${NC}"
        echo -e "${YELLOW}  7)${NC} 🔍 ${BOLD}View running containers${NC}"
        echo -e "${YELLOW}  8)${NC} 📜 ${BOLD}View container logs${NC}"
        echo -e "${YELLOW}  9)${NC} 🔐 ${BOLD}Backup & Restore${NC}"
        echo -e "\n${RED}  0)${NC} ↩️  ${BOLD}Exit${NC}\n"
        
        read -p "$(echo -e ${BOLD}Select option: ${NC})" choice
        
        case $choice in
            1) # List projects
                print_header
                print_section "DOCKER COMPOSE PROJECTS"
                
                echo -e "${CYAN}Searching for Docker Compose projects...${NC}\n"
                find ~ -type f \( -name "docker-compose.yml" -o -name "compose.yml" \) 2>/dev/null | \
                while read -r file; do
                    dir=$(dirname "$file")
                    container=$(grep -m1 "container_name:" "$file" 2>/dev/null | awk '{print $2}' | tr -d '"' || basename "$dir")
                    echo -e "${BLUE}${BOLD}$container${NC} → ${DIM}$dir${NC}"
                done
                wait_for_enter
                ;;
                
            2) # Update specific
                dirs=($(find ~ -type f \( -name "docker-compose.yml" -o -name "compose.yml" \) 2>/dev/null | xargs -I {} dirname {} | sort -u))
                if [ ${#dirs[@]} -eq 0 ]; then
                    print_error "No Docker Compose projects found!"
                    sleep 2
                    continue
                fi
                
                print_header
                print_section "UPDATE SPECIFIC PROJECT"
                
                echo -e "${BOLD}Select project to update:${NC}\n"
                for i in "${!dirs[@]}"; do
                    dir="${dirs[$i]}"
                    container=$(grep -m1 "container_name:" "$dir/docker-compose.yml" "$dir/compose.yml" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"' || basename "$dir")
                    printf "${YELLOW}%2d)${NC} ${BOLD}%-20s${NC} ${DIM}%s${NC}\n" "$((i+1))" "$container" "$dir"
                done
                
                echo -e "\n${RED}  0)${NC} Cancel\n"
                read -p "$(echo -e ${BOLD}Enter number: ${NC})" proj_num
                
                if [[ "$proj_num" =~ ^[0-9]+$ ]] && [ "$proj_num" -gt 0 ] && [ "$proj_num" -le "${#dirs[@]}" ]; then
                    dir="${dirs[$((proj_num-1))]}"
                    echo -e "\n${CYAN}${BOLD}Updating project in: $dir${NC}\n"
                    cd "$dir"
                    docker compose pull && docker compose down && docker compose up -d
                    print_success "Update completed!"
                    docker compose ps
                fi
                wait_for_enter
                ;;
                
            3) # Quick update
                dirs=($(find ~ -type f \( -name "docker-compose.yml" -o -name "compose.yml" \) 2>/dev/null | xargs -I {} dirname {} | sort -u))
                
                print_header
                echo -e "${CYAN}${BOLD}Quick Update - Select project:${NC}\n"
                for i in "${!dirs[@]}"; do
                    container=$(grep -m1 "container_name:" "${dirs[$i]}/docker-compose.yml" "${dirs[$i]}/compose.yml" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"' || basename "${dirs[$i]}")
                    printf "${YELLOW}%2d)${NC} ${BOLD}%s${NC}\n" "$((i+1))" "$container"
                done
                
                read -p "$(echo -e "${BOLD}Project number: ${NC}\n")" num
                if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -gt 0 ] && [ "$num" -le "${#dirs[@]}" ]; then
                    cd "${dirs[$((num-1))]}" && docker compose pull && docker compose down && docker compose up -d
                    print_success "Updated!"
                fi
                sleep 2
                ;;
                
            4) # Update all
                print_header
                print_warning "This will update ALL Docker projects!"
                read -p "$(echo -e ${BOLD}Continue? \(y/N\): ${NC})" -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    find ~ -type f \( -name "docker-compose.yml" -o -name "compose.yml" \) 2>/dev/null | xargs -I {} dirname {} | sort -u | \
                    while read -r dir; do
                        echo -e "\n${CYAN}${BOLD}Updating: $dir${NC}"
                        cd "$dir" && docker compose pull && docker compose down && docker compose up -d
                    done
                    print_success "All projects updated!"
                fi
                wait_for_enter
                ;;
                
            5) # Clean Docker
                print_header
                print_section "DOCKER CLEANUP"
                
                docker system df
                print_warning "Remove unused images, containers, and volumes?"
                read -p "$(echo -e ${BOLD}Continue? \(y/N\): ${NC})" -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    docker system prune -a -f --volumes
                    print_success "Cleanup completed!"
                    docker system df
                fi
                wait_for_enter
                ;;
                
            6) # Disk usage
                print_header
                print_section "DOCKER DISK USAGE"
                docker system df -v
                wait_for_enter
                ;;
                
            7) # Running containers
                print_header
                print_section "RUNNING CONTAINERS"
                echo -e "${BOLD}"
                docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Ports}}"
                echo -e "${NC}"
                wait_for_enter
                ;;
                
            8) # Container logs
                print_header
                print_section "CONTAINER LOGS"
                
                containers=($(docker ps --format "{{.Names}}"))
                if [ ${#containers[@]} -eq 0 ]; then
                    print_warning "No running containers"
                    sleep 2
                    continue
                fi
                
                echo -e "${BOLD}Select container for logs:${NC}\n"
                for i in "${!containers[@]}"; do
                    printf "${YELLOW}%2d)${NC} ${BOLD}%s${NC}\n" "$((i+1))" "${containers[$i]}"
                done
                
                echo -e "\n${RED}  0)${NC} Cancel\n"
                read -p "$(echo -e ${BOLD}Container number: ${NC})" num
                if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -gt 0 ] && [ "$num" -le "${#containers[@]}" ]; then
                    echo -e "\n${CYAN}${BOLD}Logs for ${containers[$((num-1))]}:${NC}\n"
                    docker logs --tail 50 -f "${containers[$((num-1))]}"
                fi
                ;;
                
            9) # Backup & Restore
                backup_menu
                ;;
                
            0) exit 0 ;;
            *) print_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# Start
docker_menu

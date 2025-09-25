#!/bin/bash
# Docker Manager Script - Enhanced Version
# Immediate display of all containers, projects, and disk usage
# Part of VPS Security Tools Suite
# Host as: docker-manager.sh

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed"
    echo "Please install Docker first"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker daemon is not running or you don't have permission"
    echo "Try: sudo systemctl start docker"
    echo "Or add user to docker group: sudo usermod -aG docker $USER"
    exit 1
fi

# Enhanced Colors for Better Visibility
RED='\033[1;91m'       # Bright Red
GREEN='\033[1;92m'     # Bright Green  
YELLOW='\033[1;93m'    # Bright Yellow
BLUE='\033[1;94m'      # Bright Blue
CYAN='\033[1;96m'      # Bright Cyan
MAGENTA='\033[1;95m'   # Bright Magenta
WHITE='\033[1;97m'     # Bright White
ORANGE='\033[38;5;208m' # Orange
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'           # No Color
BG_RED='\033[41m'      # Red Background
BG_GREEN='\033[42m'    # Green Background
BG_YELLOW='\033[43m'   # Yellow Background

# Unicode symbols
CHECK="✓"
CROSS="✗"
WARNING="⚠"
INFO="ℹ"
ARROW="→"
BULLET="●"
DOCKER="🐳"

# Function to print section headers
print_section() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}${BOLD}  $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Function to format bytes to human readable
format_bytes() {
    local bytes=$1
    if [ -z "$bytes" ] || [ "$bytes" = "0" ]; then
        echo "0 B"
    elif [ $bytes -lt 1024 ]; then
        echo "${bytes} B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$(( bytes / 1024 )) KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$(( bytes / 1048576 )) MB"
    else
        echo "$(echo "scale=2; $bytes / 1073741824" | bc) GB"
    fi
}

# Function to get container health status with color (simplified for speed)
get_health_status() {
    local container=$1
    local state=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
    
    if [ "$state" = "running" ]; then
        # Check if container has health check
        local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null)
        if [ "$health" = "healthy" ]; then
            echo -e "${GREEN}Healthy${NC}"
        elif [ "$health" = "unhealthy" ]; then
            echo -e "${RED}Unhealthy${NC}"
        elif [ "$health" = "starting" ]; then
            echo -e "${YELLOW}Starting${NC}"
        else
            echo -e "${GREEN}Running${NC}"
        fi
    elif [ "$state" = "exited" ]; then
        echo -e "${RED}Stopped${NC}"
    elif [ "$state" = "restarting" ]; then
        echo -e "${YELLOW}Restarting${NC}"
    else
        echo -e "${DIM}${state}${NC}"
    fi
}

# Function to get container's docker-compose project
get_compose_project() {
    local container=$1
    local project=$(docker inspect --format='{{index .Config.Labels "com.docker.compose.project"}}' "$container" 2>/dev/null)
    echo "${project:-standalone}"
}

# Function to find all docker-compose projects
find_compose_projects() {
    local home_dir="$HOME"
    find "$home_dir" -type f \( -name "docker-compose.yml" -o -name "docker-compose.yaml" -o -name "compose.yml" -o -name "compose.yaml" \) 2>/dev/null | while read -r file; do
        echo "$(dirname "$file")"
    done | sort -u
}

# Function to get project status
get_project_status() {
    local project_dir=$1
    local project_name=$(basename "$project_dir")
    
    # Try to get project name from docker-compose
    cd "$project_dir" 2>/dev/null
    if [ $? -eq 0 ]; then
        # Count services defined in compose file
        local compose_file=""
        for file in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
            if [ -f "$file" ]; then
                compose_file="$file"
                break
            fi
        done
        
        if [ -n "$compose_file" ]; then
            # Get running containers for this project
            local running_containers=$(docker compose ps -q --status running 2>/dev/null | wc -l)
            local total_containers=$(docker compose ps -q 2>/dev/null | wc -l)
            
            echo "$total_containers|$running_containers"
        else
            echo "0|0"
        fi
    else
        echo "0|0"
    fi
}

# Main display function
main_display() {
    clear
    
    # Header
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}                 ${DOCKER} DOCKER MANAGER ${DOCKER}                          ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}  $(date '+%Y-%m-%d %H:%M:%S')                                          ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    
    # Docker System Status
    print_section "DOCKER SYSTEM STATUS"
    
    # Docker version
    docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
    compose_version=$(docker compose version --short 2>/dev/null || echo "Not installed")
    
    # Container counts
    total_containers=$(docker ps -aq | wc -l)
    running_containers=$(docker ps -q | wc -l)
    stopped_containers=$((total_containers - running_containers))
    
    # Image count
    total_images=$(docker images -q | wc -l)
    
    # Volume count
    total_volumes=$(docker volume ls -q | wc -l)
    
    echo -e "${BLUE}  Docker Version:${NC} ${WHITE}${docker_version}${NC}"
    echo -e "${BLUE}  Compose Version:${NC} ${WHITE}${compose_version}${NC}"
    echo -e "${BLUE}  Status:${NC} ${GREEN}Running ${CHECK}${NC}"
    echo ""
    echo -e "${BLUE}  Containers:${NC} ${GREEN}${running_containers} running${NC}, ${YELLOW}${stopped_containers} stopped${NC} (${WHITE}${total_containers} total${NC})"
    echo -e "${BLUE}  Images:${NC} ${WHITE}${total_images}${NC}"
    echo -e "${BLUE}  Volumes:${NC} ${WHITE}${total_volumes}${NC}"
    
    # All Containers (Grouped by Docker Compose Project) - FASTER VERSION
    print_section "ALL CONTAINERS (Grouped by Project)"
    
    # Get all containers with their projects
    declare -A projects
    declare -A container_info
    
    # First, get all containers and their basic info in one go
    while IFS='|' read -r name project state ports; do
        if [ -n "$name" ]; then
            if [ -z "$project" ] || [ "$project" = "<no value>" ]; then
                project="standalone"
            fi
            
            if [ -z "${projects[$project]}" ]; then
                projects[$project]="$name"
            else
                projects[$project]="${projects[$project]}:$name"
            fi
            
            # Store container info for later use
            container_info["${name}_state"]="$state"
            container_info["${name}_ports"]="$ports"
        fi
    done < <(docker ps -a --format "{{.Names}}|{{.Label \"com.docker.compose.project\"}}|{{.State}}|{{.Ports}}")
    
    # Display containers grouped by project
    for project in $(echo "${!projects[@]}" | tr ' ' '\n' | sort); do
        # Project header
        if [ "$project" = "standalone" ]; then
            echo -e "${MAGENTA}${BOLD}  ▶ Standalone Containers${NC}"
        else
            echo -e "${MAGENTA}${BOLD}  ▶ Project: ${project}${NC}"
        fi
        
        # Table header with fixed widths
        printf "    ${WHITE}${BOLD}%-30s %-20s %-25s${NC}\n" \
            "Name" "Status" "Ports"
        printf "    ${DIM}%s${NC}\n" "──────────────────────────────────────────────────────────────────"
        
        # Display containers for this project
        IFS=':' read -ra containers <<< "${projects[$project]}"
        for container in "${containers[@]}"; do
            # Get stored state
            state="${container_info[${container}_state]}"
            
            # Convert state to colored status
            if [ "$state" = "running" ]; then
                status="${GREEN}Running${NC}"
            elif [ "$state" = "exited" ]; then
                status="${RED}Stopped${NC}"
            elif [ "$state" = "restarting" ]; then
                status="${YELLOW}Restarting${NC}"
            else
                status="${DIM}${state}${NC}"
            fi
            
            # Parse ports
            ports_raw="${container_info[${container}_ports]}"
            if [ -n "$ports_raw" ] && [ "$ports_raw" != "<no value>" ]; then
                # Extract port numbers from the format "0.0.0.0:8080->8080/tcp"
                ports=$(echo "$ports_raw" | grep -oE '[0-9]+(->[0-9]+)' | grep -oE '^[0-9]+' | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
                [ -z "$ports" ] && ports="-"
            else
                ports="-"
            fi
            
            # Truncate long values if needed
            container_display="${container:0:30}"
            ports_display="${ports:0:25}"
            
            # Print container info with proper alignment
            printf "    %-30s %-20b %-25s\n" \
                "$container_display" "$status" "$ports_display"
        done
        echo ""
    done
    
    # Docker Compose Projects
    print_section "DOCKER COMPOSE PROJECTS"
    
    printf "  ${WHITE}${BOLD}%-30s %-40s %-20s %-15s${NC}\n" \
        "Project" "Path" "Containers" "Status"
    printf "  ${DIM}%s${NC}\n" "──────────────────────────────────────────────────────────────────────────────────────────────────"
    
    # Find all docker-compose projects
    compose_projects=$(find_compose_projects)
    
    if [ -z "$compose_projects" ]; then
        echo -e "${DIM}  No docker-compose projects found${NC}"
    else
        echo "$compose_projects" | while read -r project_dir; do
            if [ -n "$project_dir" ]; then
                project_name=$(basename "$project_dir")
                
                # Get project status
                status_info=$(get_project_status "$project_dir")
                IFS='|' read -r total running <<< "$status_info"
                
                # Determine status color and icon
                if [ "$total" -eq 0 ]; then
                    status_text="${DIM}No containers${NC}"
                    containers_info="${DIM}0/0${NC}"
                elif [ "$running" -eq "$total" ] && [ "$running" -gt 0 ]; then
                    status_text="${GREEN}Healthy ${CHECK}${NC}"
                    containers_info="${GREEN}${running}/${total} running${NC}"
                elif [ "$running" -eq 0 ]; then
                    status_text="${RED}Stopped ${CROSS}${NC}"
                    containers_info="${RED}0/${total} stopped${NC}"
                else
                    status_text="${YELLOW}Partial ${WARNING}${NC}"
                    containers_info="${YELLOW}${running}/${total} running${NC}"
                fi
                
                # Truncate path if too long
                display_path="$project_dir"
                if [ ${#display_path} -gt 40 ]; then
                    display_path="...${display_path: -37}"
                fi
                
                printf "  %-30s %-40s %-20b %-15b\n" \
                    "${project_name:0:30}" \
                    "${display_path}" \
                    "$containers_info" \
                    "$status_text"
            fi
        done
    fi
    
    # Disk Usage Analysis - FIXED VERSION
    print_section "DISK USAGE ANALYSIS"
    
    # Get disk usage in a more reliable way
    echo -e "${WHITE}${BOLD}  Type          Count    Active    Size         Reclaimable${NC}"
    echo -e "${DIM}  ──────────────────────────────────────────────────────────────${NC}"
    
    # Parse docker system df output more carefully
    docker system df 2>/dev/null | tail -n +2 | head -n 4 | while IFS= read -r line; do
        if [[ "$line" =~ ^Images ]] || [[ "$line" =~ ^Containers ]] || [[ "$line" =~ ^Local\ Volumes ]] || [[ "$line" =~ ^Build\ Cache ]]; then
            # Extract values from the line
            type=$(echo "$line" | awk '{print $1}')
            if [ "$type" = "Local" ]; then
                type="Volumes"
                count=$(echo "$line" | awk '{print $3}')
                active=$(echo "$line" | awk '{print $4}')
                size=$(echo "$line" | awk '{print $5, $6}')
                reclaim=$(echo "$line" | awk '{print $7, $8}' | tr -d '()')
            elif [ "$type" = "Build" ]; then
                type="Cache"
                count=$(echo "$line" | awk '{print $3}')
                active=$(echo "$line" | awk '{print $3}')  # Build cache doesn't have active count
                size=$(echo "$line" | awk '{print $4, $5}')
                reclaim=$(echo "$line" | awk '{print $6, $7}' | tr -d '()')
            else
                count=$(echo "$line" | awk '{print $2}')
                active=$(echo "$line" | awk '{print $3}')
                size=$(echo "$line" | awk '{print $4, $5}')
                reclaim=$(echo "$line" | awk '{print $6, $7}' | tr -d '()')
            fi
            
            # Format the output
            [ -z "$reclaim" ] && reclaim="0B"
            [ -z "$active" ] && active="N/A"
            
            # Color code based on type
            case $type in
                Images)
                    type_color="${BLUE}"
                    ;;
                Containers)
                    type_color="${GREEN}"
                    ;;
                Volumes)
                    type_color="${YELLOW}"
                    ;;
                Cache)
                    type_color="${MAGENTA}"
                    ;;
                *)
                    type_color="${WHITE}"
                    ;;
            esac
            
            printf "  ${type_color}%-13s${NC} %-8s %-9s %-12s ${DIM}%s${NC}\n" \
                "$type" "$count" "$active" "$size" "$reclaim"
        fi
    done
    
    # Calculate total properly
    echo -e "${DIM}  ──────────────────────────────────────────────────────────────${NC}"
    
    # Get total from docker system df
    total_output=$(docker system df 2>/dev/null | grep "^TOTAL" || docker system df --format "table" 2>/dev/null | tail -1)
    
    if [ -n "$total_output" ]; then
        # Try to parse TOTAL line if it exists
        if [[ "$total_output" =~ TOTAL ]]; then
            total_size=$(echo "$total_output" | awk '{print $2, $3}')
            total_reclaim=$(echo "$total_output" | awk '{print $4, $5}' | tr -d '()')
        else
            # Fallback: sum up individual components
            total_size=$(docker system df --format "{{.Size}}" 2>/dev/null | paste -sd+ | bc 2>/dev/null || echo "0")
            if [ "$total_size" != "0" ]; then
                # Convert bytes to human readable
                if [ "$total_size" -gt 1073741824 ]; then
                    total_size=$(echo "scale=2; $total_size / 1073741824" | bc)" GB"
                elif [ "$total_size" -gt 1048576 ]; then
                    total_size=$(echo "scale=2; $total_size / 1048576" | bc)" MB"
                else
                    total_size="${total_size} B"
                fi
            else
                # Last resort: get from verbose output
                total_size=$(docker system df -v 2>/dev/null | grep "TOTAL" | awk '{print $2, $3}')
                [ -z "$total_size" ] && total_size="N/A"
            fi
            total_reclaim=$(docker system df --format "{{.Reclaimable}}" 2>/dev/null | tail -1)
        fi
    else
        total_size="N/A"
        total_reclaim="0B"
    fi
    
    [ -z "$total_reclaim" ] && total_reclaim="0B"
    
    printf "  ${WHITE}${BOLD}%-13s %-8s %-9s %-12s ${DIM}%s${NC}\n" \
        "TOTAL" "-" "-" "$total_size" "$total_reclaim"
    
    # Show warning if reclaimable space is significant
    if [ -n "$total_reclaim" ] && [ "$total_reclaim" != "0B" ] && [ "$total_reclaim" != "0" ]; then
        # Check if reclaimable is more than 100MB
        reclaim_value=$(echo "$total_reclaim" | grep -oE '[0-9.]+' | head -1)
        reclaim_unit=$(echo "$total_reclaim" | grep -oE '[A-Z]+' | head -1)
        
        show_warning=false
        if [ "$reclaim_unit" = "GB" ]; then
            show_warning=true
        elif [ "$reclaim_unit" = "MB" ]; then
            if (( $(echo "$reclaim_value > 100" | bc -l) )); then
                show_warning=true
            fi
        fi
        
        if [ "$show_warning" = true ]; then
            echo ""
            echo -e "${YELLOW}  ${WARNING} ${total_reclaim} can be reclaimed by cleaning${NC}"
        fi
    fi
}

# Function to update a project
update_project() {
    print_section "UPDATE DOCKER PROJECT"
    
    # Find all docker-compose projects
    compose_projects=$(find_compose_projects)
    
    if [ -z "$compose_projects" ]; then
        echo -e "${RED}No docker-compose projects found!${NC}"
        return
    fi
    
    # Create array of projects
    projects=()
    while IFS= read -r project; do
        projects+=("$project")
    done <<< "$compose_projects"
    
    echo -e "${WHITE}${BOLD}Select project to update:${NC}"
    echo ""
    
    # List projects
    for i in "${!projects[@]}"; do
        project_dir="${projects[$i]}"
        project_name=$(basename "$project_dir")
        
        # Get project status
        status_info=$(get_project_status "$project_dir")
        IFS='|' read -r total running <<< "$status_info"
        
        # Status indicator
        if [ "$running" -eq "$total" ] && [ "$running" -gt 0 ]; then
            status_color="${GREEN}"
            status_text="[${running}/${total} running]"
        elif [ "$running" -eq 0 ]; then
            status_color="${RED}"
            status_text="[stopped]"
        else
            status_color="${YELLOW}"
            status_text="[${running}/${total} running]"
        fi
        
        printf "  ${YELLOW}%2d)${NC} %-25s ${status_color}%-20s${NC} ${DIM}%s${NC}\n" \
            "$((i+1))" "$project_name" "$status_text" "$project_dir"
    done
    
    echo ""
    echo -e "  ${RED}0)${NC} Cancel"
    echo ""
    
    read -p "$(echo -e ${YELLOW}${BOLD}'Select project number: '${NC})" choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le "${#projects[@]}" ]; then
        project_dir="${projects[$((choice-1))]}"
        project_name=$(basename "$project_dir")
        
        echo ""
        echo -e "${CYAN}${BOLD}Updating project: ${project_name}${NC}"
        echo -e "${DIM}Path: ${project_dir}${NC}"
        echo ""
        
        # Change to project directory
        cd "$project_dir" || return
        
        # Show current images
        echo -e "${BLUE}Current images:${NC}"
        docker compose images
        echo ""
        
        # Pull latest images
        echo -e "${YELLOW}Pulling latest images...${NC}"
        docker compose pull
        
        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${YELLOW}Recreating containers with new images...${NC}"
            docker compose up -d
            
            if [ $? -eq 0 ]; then
                echo ""
                echo -e "${GREEN}${CHECK} Update completed successfully!${NC}"
                echo ""
                echo -e "${BLUE}Updated containers:${NC}"
                docker compose ps
            else
                echo -e "${RED}${CROSS} Failed to recreate containers${NC}"
            fi
        else
            echo -e "${RED}${CROSS} Failed to pull images${NC}"
        fi
    fi
}

# Function to clean Docker
clean_docker() {
    print_section "CLEAN DOCKER SYSTEM"
    
    echo -e "${WHITE}${BOLD}Current disk usage:${NC}"
    echo ""
    docker system df
    echo ""
    
    # Show what will be cleaned
    echo -e "${YELLOW}${BOLD}This will remove (SAFE - Level 1):${NC}"
    echo -e "  ${BULLET} All stopped containers"
    echo -e "  ${BULLET} All networks not used by containers"
    echo -e "  ${BULLET} All dangling images"
    echo -e "  ${BULLET} All dangling build cache"
    echo ""
    echo -e "${GREEN}${INFO} Your volumes and running containers will NOT be affected${NC}"
    echo ""
    
    # Preview what will be deleted
    echo -e "${BLUE}Preview of items to be removed:${NC}"
    echo ""
    
    # Stopped containers
    stopped=$(docker ps -a -q -f status=exited | wc -l)
    if [ "$stopped" -gt 0 ]; then
        echo -e "${YELLOW}  Stopped containers: ${stopped}${NC}"
        docker ps -a -f status=exited --format "    - {{.Names}} ({{.Image}})" | head -5
        [ "$stopped" -gt 5 ] && echo "    ... and $((stopped - 5)) more"
    fi
    
    # Dangling images
    dangling=$(docker images -f "dangling=true" -q | wc -l)
    if [ "$dangling" -gt 0 ]; then
        echo -e "${YELLOW}  Dangling images: ${dangling}${NC}"
    fi
    
    # Unused networks
    unused_nets=$(docker network ls -q -f "dangling=true" | wc -l)
    if [ "$unused_nets" -gt 0 ]; then
        echo -e "${YELLOW}  Unused networks: ${unused_nets}${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}${BOLD}Proceed with cleanup? (y/N):${NC} "
    read -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cleaning Docker system...${NC}"
        echo ""
        
        # Run cleanup
        docker system prune -f
        
        echo ""
        echo -e "${GREEN}${CHECK} Cleanup completed!${NC}"
        echo ""
        echo -e "${WHITE}${BOLD}New disk usage:${NC}"
        echo ""
        docker system df
    else
        echo -e "${DIM}Cleanup cancelled${NC}"
    fi
}

# Function to view logs with color highlighting
view_logs() {
    print_section "VIEW CONTAINER LOGS"
    
    # Get all containers
    containers=($(docker ps -a --format "{{.Names}}"))
    
    if [ ${#containers[@]} -eq 0 ]; then
        echo -e "${RED}No containers found${NC}"
        return
    fi
    
    echo -e "${WHITE}${BOLD}Select container:${NC}"
    echo ""
    
    # List containers with status
    for i in "${!containers[@]}"; do
        container="${containers[$i]}"
        status=$(get_health_status "$container")
        project=$(get_compose_project "$container")
        
        printf "  ${YELLOW}%2d)${NC} %-30s %-20b ${DIM}[%s]${NC}\n" \
            "$((i+1))" "$container" "$status" "$project"
    done
    
    echo ""
    echo -e "  ${RED}0)${NC} Cancel"
    echo ""
    
    read -p "$(echo -e ${YELLOW}${BOLD}'Select container number: '${NC})" choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -gt 0 ] && [ "$choice" -le "${#containers[@]}" ]; then
        container="${containers[$((choice-1))]}"
        
        echo ""
        echo -e "${CYAN}${BOLD}Logs for: ${container}${NC}"
        echo ""
        
        # Show last 1 hour by default
        echo -e "${BLUE}Showing logs from last hour:${NC}"
        echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        docker logs --since "1h" "$container" 2>&1 | \
            sed -E "s/(error|ERROR|Error|fail|FAIL|Fail|failed|FAILED|Failed|fatal|FATAL|Fatal|panic|PANIC|Panic)/${RED}&${NC}/g" | \
            sed -E "s/(warning|WARNING|Warning|warn|WARN|Warn)/${YELLOW}&${NC}/g" | \
            sed -E "s/(info|INFO|Info)/${BLUE}&${NC}/g" | \
            sed -E "s/([4-5][0-9]{2})/${RED}&${NC}/g"
        
        echo ""
        echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        # Now offer other time range options
        echo -e "${WHITE}${BOLD}View different time range?${NC}"
        echo -e "  ${YELLOW}1)${NC} Today"
        echo -e "  ${YELLOW}2)${NC} Yesterday"
        echo -e "  ${YELLOW}3)${NC} Last 5 days"
        echo -e "  ${YELLOW}4)${NC} Last 100 lines"
        echo -e "  ${YELLOW}5)${NC} Follow live"
        echo -e "  ${YELLOW}6)${NC} Continue (skip)"
        echo ""
        
        read -p "$(echo -e ${YELLOW}${BOLD}'Select option (1-6): '${NC})" time_choice
        
        case $time_choice in
            1) # Today
                echo ""
                echo -e "${BLUE}Showing logs from today:${NC}"
                echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
                echo ""
                docker logs --since "$(date '+%Y-%m-%d')T00:00:00" "$container" 2>&1 | \
                    sed -E "s/(error|ERROR|Error|fail|FAIL|Fail|failed|FAILED|Failed|fatal|FATAL|Fatal|panic|PANIC|Panic)/${RED}&${NC}/g" | \
                    sed -E "s/(warning|WARNING|Warning|warn|WARN|Warn)/${YELLOW}&${NC}/g" | \
                    sed -E "s/(info|INFO|Info)/${BLUE}&${NC}/g" | \
                    sed -E "s/([4-5][0-9]{2})/${RED}&${NC}/g"
                ;;
            2) # Yesterday
                echo ""
                echo -e "${BLUE}Showing logs from yesterday:${NC}"
                echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
                echo ""
                docker logs --since "$(date -d yesterday '+%Y-%m-%d')T00:00:00" \
                           --until "$(date '+%Y-%m-%d')T00:00:00" "$container" 2>&1 | \
                    sed -E "s/(error|ERROR|Error|fail|FAIL|Fail|failed|FAILED|Failed|fatal|FATAL|Fatal|panic|PANIC|Panic)/${RED}&${NC}/g" | \
                    sed -E "s/(warning|WARNING|Warning|warn|WARN|Warn)/${YELLOW}&${NC}/g" | \
                    sed -E "s/(info|INFO|Info)/${BLUE}&${NC}/g" | \
                    sed -E "s/([4-5][0-9]{2})/${RED}&${NC}/g"
                ;;
            3) # Last 5 days
                echo ""
                echo -e "${BLUE}Showing logs from last 5 days:${NC}"
                echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
                echo ""
                docker logs --since "$(date -d '5 days ago' '+%Y-%m-%d')T00:00:00" "$container" 2>&1 | \
                    sed -E "s/(error|ERROR|Error|fail|FAIL|Fail|failed|FAILED|Failed|fatal|FATAL|Fatal|panic|PANIC|Panic)/${RED}&${NC}/g" | \
                    sed -E "s/(warning|WARNING|Warning|warn|WARN|Warn)/${YELLOW}&${NC}/g" | \
                    sed -E "s/(info|INFO|Info)/${BLUE}&${NC}/g" | \
                    sed -E "s/([4-5][0-9]{2})/${RED}&${NC}/g"
                ;;
            4) # Last 100 lines
                echo ""
                echo -e "${BLUE}Showing last 100 lines:${NC}"
                echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
                echo ""
                docker logs --tail 100 "$container" 2>&1 | \
                    sed -E "s/(error|ERROR|Error|fail|FAIL|Fail|failed|FAILED|Failed|fatal|FATAL|Fatal|panic|PANIC|Panic)/${RED}&${NC}/g" | \
                    sed -E "s/(warning|WARNING|Warning|warn|WARN|Warn)/${YELLOW}&${NC}/g" | \
                    sed -E "s/(info|INFO|Info)/${BLUE}&${NC}/g" | \
                    sed -E "s/([4-5][0-9]{2})/${RED}&${NC}/g"
                ;;
            5) # Follow
                echo ""
                echo -e "${BLUE}Following live logs (Ctrl+C to stop):${NC}"
                echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
                echo ""
                docker logs -f --tail 50 "$container" 2>&1 | \
                    sed -E "s/(error|ERROR|Error|fail|FAIL|Fail|failed|FAILED|Failed|fatal|FATAL|Fatal|panic|PANIC|Panic)/${RED}&${NC}/g" | \
                    sed -E "s/(warning|WARNING|Warning|warn|WARN|Warn)/${YELLOW}&${NC}/g" | \
                    sed -E "s/(info|INFO|Info)/${BLUE}&${NC}/g" | \
                    sed -E "s/([4-5][0-9]{2})/${RED}&${NC}/g"
                ;;
            6) # Continue
                # Do nothing, just continue
                ;;
            *)
                # Invalid option or empty, just continue
                ;;
        esac
        
        echo ""
        echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
    fi
}

# Show actions menu
show_actions() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}  AVAILABLE ACTIONS${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${YELLOW}U)${NC} Update specific project"
    echo -e "  ${YELLOW}C)${NC} Clean Docker (safe)"
    echo -e "  ${YELLOW}L)${NC} View container logs"
    echo -e "  ${YELLOW}R)${NC} Refresh display"
    echo -e "  ${YELLOW}Q)${NC} Quit"
    echo ""
    echo -e "${DIM}────────────────────────────────────────────────────────────────────${NC}"
    echo ""
}

# Main execution
main() {
    # Show main display first
    main_display
    
    # Then show action menu
    while true; do
        show_actions
        read -p "$(echo -e ${YELLOW}${BOLD}'Select action: '${NC})" action
        
        case ${action,,} in
            u)
                update_project
                echo ""
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                main_display
                ;;
            c)
                clean_docker
                echo ""
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                main_display
                ;;
            l)
                view_logs
                echo ""
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                main_display
                ;;
            r)
                main_display
                ;;
            q)
                echo ""
                echo -e "${GREEN}${BOLD}Goodbye! 🐳${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

# Check for help
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Docker Manager Script"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -w, --watch    Auto-refresh every 10 seconds"
    echo ""
    exit 0
fi

# Check for watch mode
if [[ "$1" == "-w" ]] || [[ "$1" == "--watch" ]]; then
    while true; do
        main_display
        echo ""
        echo -e "${DIM}Auto-refresh in 10 seconds... Press Ctrl+C to stop${NC}"
        sleep 10
    done
else
    main
fi

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

            # Parse ports - fixed to avoid duplicates
            ports_raw="${container_info[${container}_ports]}"
            if [ -n "$ports_raw" ] && [ "$ports_raw" != "<no value>" ]; then
                # Extract unique port numbers from the format "0.0.0.0:8080->8080/tcp"
                ports=$(echo "$ports_raw" | grep -oE ':[0-9]+->|^[0-9]+->' | grep -oE '[0-9]+' | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
                [ -z "$ports" ] && ports="-"
            else
                ports="-"
            fi

            # Truncate long values if needed
            container_display="${container:0:30}"

            # Print container info with proper alignment
            printf "    %-30s %-32b %s\n" \
                "$container_display" "$status" "$ports"
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

    # Disk Usage Analysis - COMPLETELY FIXED VERSION
    print_section "DISK USAGE ANALYSIS"

    echo -e "${WHITE}${BOLD}  Type          Count    Active    Size         Reclaimable${NC}"
    echo -e "${DIM}  ──────────────────────────────────────────────────────────────${NC}"

    df_output=$(docker system df --format "{{.Type}}|{{.TotalCount}}|{{.Active}}|{{.Size}}|{{.Reclaimable}}" 2>/dev/null)
    reclaimable_space_warning=""

    declare -A type_colors
    type_colors["Images"]="BLUE"
    type_colors["Containers"]="GREEN"
    type_colors["Local Volumes"]="YELLOW"
    type_colors["Build Cache"]="MAGENTA"

    while IFS='|' read -r type count active size reclaim; do
        if [[ "$type" == "Local Volumes" ]]; then
            type_display="Volumes"
        elif [[ "$type" == "Build Cache" ]]; then
            type_display="Cache"
        else
            type_display="$type"
        fi

        color_var_name=${type_colors[$type]:-WHITE}
        color_var="${!color_var_name}"

        reclaim_display=$(echo "$reclaim" | sed 's/ (.*)//')
        [ -z "$reclaim_display" ] && reclaim_display="0B"

        if [[ "$reclaim_display" =~ GB|MB ]]; then
            reclaimable_space_warning="true"
        fi

        if [[ "$type" == "Build Cache" ]]; then
            active="N/A"
        fi

        printf "  ${color_var}%-13s${NC} %-8s %-9s %-12s ${DIM}%s${NC}\n" \
            "$type_display" "$count" "$active" "$size" "$reclaim_display"

    done <<< "$df_output"

    echo -e "${DIM}  ──────────────────────────────────────────────────────────────${NC}"

    if [[ "$reclaimable_space_warning" == "true" ]]; then
        echo ""
        echo -e "${YELLOW}  ${WARNING} Significant space can be reclaimed by cleaning${NC}"
    fi
}

# IMPROVEMENT: A more robust, communicative, and safe update function
update_project() {
    print_section "UPDATE DOCKER PROJECT"

    compose_projects=$(find_compose_projects)

    if [ -z "$compose_projects" ]; then
        echo -e "${RED}No docker-compose projects found!${NC}"
        return
    fi

    projects=()
    while IFS= read -r project; do
        projects+=("$project")
    done <<< "$compose_projects"

    echo -e "${WHITE}${BOLD}Select project to update:${NC}"
    echo ""

    for i in "${!projects[@]}"; do
        project_dir="${projects[$i]}"
        project_name=$(basename "$project_dir")
        status_info=$(get_project_status "$project_dir")
        IFS='|' read -r total running <<< "$status_info"

        if [ "$running" -eq "$total" ] && [ "$running" -gt 0 ]; then
            status_color="${GREEN}"; status_text="[${running}/${total} running]"
        elif [ "$running" -eq 0 ]; then
            status_color="${RED}"; status_text="[stopped]"
        else
            status_color="${YELLOW}"; status_text="[${running}/${total} running]"
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

        cd "$project_dir" || return

        # --- IMPROVEMENT 1: PRE-FLIGHT CHECK ---
        # Verify the docker-compose file is valid before doing anything else.
        echo ""
        echo -e "${DIM}Verifying compose file syntax...${NC}"
        if ! docker compose config -q >/dev/null 2>&1; then
            echo -e "${RED}${CROSS} Error: The docker-compose.yml file in '${project_name}' has a syntax error.${NC}"
            echo -e "${RED}Please fix the file before attempting an update.${NC}"
            return
        fi
        echo -e "${GREEN}${CHECK} Compose file is valid.${NC}"

        # --- IMPROVEMENT 2: DATA SAFETY WARNING ---
        echo ""
        echo -e "${ORANGE}${WARNING} ${BOLD}Data Safety Notice${NC}"
        echo -e "${DIM}  This script assumes your service data is stored in Docker Volumes.${NC}"
        echo -e "${DIM}  The update process replaces containers but re-attaches existing volumes.${NC}"
        echo -e "${DIM}  Ensure all stateful services (like databases) use volumes to prevent data loss.${NC}"
        echo ""
        read -p "$(echo -e ${YELLOW}${BOLD}"Are you sure you want to update '${project_name}'? (y/N): "${NC})" confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo -e "${DIM}Update cancelled.${NC}"
            return
        fi

        echo ""
        echo -e "${CYAN}${BOLD}Updating project: ${project_name}${NC}"
        
        # --- IMPROVEMENT 3: CAPTURE STATE BEFORE UPDATE ---
        declare -A before_images
        while IFS=' ' read -r service image; do
            [ -n "$service" ] && before_images[$service]=$image
        done < <(docker compose ps --services | xargs -n 1 docker compose ps -q | xargs -n 1 docker inspect --format '{{.Name}} {{.Image}}' | sed 's|/||' | sed 's/-[0-9]*$//')


        echo -e "${YELLOW}Pulling latest images...${NC}"
        if docker compose pull; then
            echo ""
            echo -e "${YELLOW}Recreating containers (if needed)...${NC}"
            
            # Run the update
            if docker compose up -d --remove-orphans; then
                echo ""
                echo -e "${GREEN}${CHECK} Deployment completed successfully!${NC}"
                
                # --- IMPROVEMENT 4: COMPARE STATE AND SHOW DIFF ---
                declare -A after_images
                while IFS=' ' read -r service image; do
                    [ -n "$service" ] && after_images[$service]=$image
                done < <(docker compose ps --services | xargs -n 1 docker compose ps -q | xargs -n 1 docker inspect --format '{{.Name}} {{.Image}}' | sed 's|/||' | sed 's/-[0-9]*$//')


                echo ""
                echo -e "${WHITE}${BOLD}Update Summary:${NC}"
                updated_count=0
                for service in "${!after_images[@]}"; do
                    before_sha=${before_images[$service]}
                    after_sha=${after_images[$service]}

                    if [ "$before_sha" != "$after_sha" ]; then
                        printf "  ${GREEN}${BULLET} %-25s updated from %s to %s${NC}\n" "$service" "${before_sha:7:19}" "${after_sha:7:19}"
                        ((updated_count++))
                    fi
                done

                if [ $updated_count -eq 0 ]; then
                    echo -e "${DIM}  No services were updated. All images are current.${NC}"
                fi

                # Offer to prune dangling images post-update
                dangling_images=$(docker images -f "dangling=true" -q | wc -l)
                if [ "$dangling_images" -gt 0 ]; then
                    echo ""
                    read -p "$(echo -e ${YELLOW}${BOLD}"Prune ${dangling_images} old image layers to save space? (y/N): "${NC})" prune_choice
                    if [[ "$prune_choice" =~ ^[Yy]$ ]]; then
                        docker image prune -f
                        echo -e "${GREEN}Old images pruned.${NC}"
                    fi
                fi
            else
                # --- IMPROVEMENT 5: INTELLIGENT FAILURE GUIDANCE ---
                echo ""
                echo -e "${RED}${CROSS} FAILED TO RECREATE CONTAINERS!${NC}"
                echo -e "${YELLOW}The project may be in a non-running state.${NC}"
                echo -e "To diagnose, check the logs of the failed container(s)."
                # Find containers that are stopped/exited and suggest logging them
                while read -r container_id; do
                    container_name=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's|/||')
                    echo -e "${CYAN}  Try running: ${WHITE}docker logs ${container_name}${NC}"
                done < <(docker compose ps -q --status exited --status created)
            fi
        else
            echo -e "${RED}${CROSS} Failed to pull new images. Aborting update.${NC}"
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

    echo -e "${YELLOW}${BOLD}This will perform a safe cleanup, removing:${NC}"
    echo -e "  ${BULLET} All stopped containers"
    echo -e "  ${BULLET} All networks not used by containers"
    echo -e "  ${BULLET} All dangling images (unused layers)"
    echo -e "  ${BULLET} All dangling build cache"
    echo ""
    echo -e "${GREEN}${INFO} Your named volumes and running containers will NOT be affected.${NC}"
    echo ""

    read -p "$(echo -e ${YELLOW}${BOLD}'Proceed with standard cleanup? (y/N): '${NC})" confirm_prune

    local reclaimed_space="Total reclaimed space: 0B"

    if [[ "$confirm_prune" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Running standard cleanup...${NC}"
        local prune_output
        prune_output=$(docker system prune -f)
        
        echo -e "${DIM}${prune_output}${NC}"

        reclaimed_space=$(echo "$prune_output" | tail -n 1)
        echo -e "${GREEN}${CHECK} Standard cleanup complete.${NC}"
    else
        echo -e "${DIM}Standard cleanup cancelled.${NC}"
    fi

    dangling_volumes=$(docker volume ls -qf dangling=true | wc -l)
    if [ "$dangling_volumes" -gt 0 ]; then
        echo ""
        echo -e "${ORANGE}${WARNING} FOUND ${dangling_volumes} UNUSED VOLUMES${NC}"
        echo -e "${DIM}  Unused volumes are not attached to any container and may contain old data.${NC}"
        docker volume ls -qf dangling=true | xargs --no-run-if-empty docker volume inspect --format '  - {{.Name}} (Created: {{.CreatedAt}})' | head -5
        if [ "$dangling_volumes" -gt 5 ]; then
            echo "  ... and $((dangling_volumes - 5)) more."
        fi
        echo ""
        read -p "$(echo -e ${RED}${BOLD}'DELETE these unused volumes? This cannot be undone. (y/N): '${NC})" confirm_vol_prune
        if [[ "$confirm_vol_prune" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Removing unused volumes...${NC}"
            docker volume prune -f
            echo -e "${GREEN}${CHECK} Unused volumes removed.${NC}"
        else
            echo -e "${DIM}Volume cleanup skipped.${NC}"
        fi
    fi

    echo ""
    echo -e "${WHITE}${BOLD}Disk usage after cleanup:${NC}"
    echo ""
    docker system df
    echo ""

    echo -e "${GREEN}${CHECK} Cleanup finished! ${BOLD}${reclaimed_space}${NC}"
}


# Function to view logs with color highlighting
view_logs() {
    print_section "VIEW CONTAINER LOGS"

    containers=($(docker ps -a --format "{{.Names}}"))

    if [ ${#containers[@]} -eq 0 ]; then
        echo -e "${RED}No containers found${NC}"
        return
    fi

    echo -e "${WHITE}${BOLD}Select container:${NC}"
    echo ""

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

        while true; do
            clear
            echo -e "${CYAN}${BOLD}Logs for: ${container}${NC}"
            echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
            echo ""
            echo -e "${WHITE}${BOLD}Select a time range to view:${NC}"
            echo -e "  ${YELLOW}1)${NC} Last hour"
            echo -e "  ${YELLOW}2)${NC} Today"
            echo -e "  ${YELLOW}3)${NC} Yesterday"
            echo -e "  ${YELLOW}4)${NC} Last 5 days"
            echo -e "  ${YELLOW}5)${NC} Last 100 lines"
            echo -e "  ${YELLOW}6)${NC} Follow live"
            echo ""
            echo -e "  ${RED}0)${NC} Back to Main Menu"
            echo ""

            read -p "$(echo -e ${YELLOW}${BOLD}'Select option: '${NC})" time_choice

            local log_command=""
            local header=""

            case $time_choice in
                1) header="Showing logs from last hour:"; log_command="docker logs --since 1h '$container' 2>&1";;
                2) header="Showing logs from today:"; log_command="docker logs --since \"$(date '+%Y-%m-%d')T00:00:00\" '$container' 2>&1";;
                3) header="Showing logs from yesterday:"; log_command="docker logs --since \"$(date -d yesterday '+%Y-%m-%d')T00:00:00\" --until \"$(date '+%Y-%m-%d')T00:00:00\" '$container' 2>&1";;
                4) header="Showing logs from last 5 days:"; log_command="docker logs --since \"$(date -d '5 days ago' '+%Y-%m-%d')T00:00:00\" '$container' 2>&1";;
                5) header="Showing last 100 lines:"; log_command="docker logs --tail 100 '$container' 2>&1";;
                6)
                    clear
                    echo -e "${BLUE}Following live logs for ${container} (Ctrl+C to stop):${NC}"
                    echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
                    echo ""
                    docker logs -f --tail 50 "$container" 2>&1 | \
                        sed -E "s/\b(ERROR|error|Error|FAIL|fail|Fail|FAILED|failed|Failed|FATAL|fatal|Fatal|PANIC|panic|Panic)\b/$(printf '\033[1;91m')&$(printf '\033[0m')/g" | \
                        sed -E "s/\b(WARNING|warning|Warning|WARN|warn|Warn)\b/$(printf '\033[1;93m')&$(printf '\033[0m')/g" | \
                        sed -E "s/\b(INFO|info|Info)\b/$(printf '\033[1;94m')&$(printf '\033[0m')/g" | \
                        sed -E "s/\b([4-5][0-9]{2})\b/$(printf '\033[1;91m')&$(printf '\033[0m')/g"
                    continue
                    ;;
                0) break;;
                *) echo -e "${RED}Invalid option. Please try again.${NC}"; sleep 2; continue;;
            esac

            if [ -n "$log_command" ]; then
                clear
                echo -e "${BLUE}${header}${NC}"
                echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
                echo ""
                eval "$log_command" | \
                    sed -E "s/\b(ERROR|error|Error|FAIL|fail|Fail|FAILED|failed|Failed|FATAL|fatal|Fatal|PANIC|panic|Panic)\b/$(printf '\033[1;91m')&$(printf '\033[0m')/g" | \
                    sed -E "s/\b(WARNING|warning|Warning|WARN|warn|Warn)\b/$(printf '\033[1;93m')&$(printf '\033[0m')/g" | \
                    sed -E "s/\b(INFO|info|Info)\b/$(printf '\033[1;94m')&$(printf '\033[0m')/g" | \
                    sed -E "s/\b([4-5][0-9]{2})\b/$(printf '\033[1;91m')&$(printf '\033[0m')/g"

                echo ""
                echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
                read -p "$(echo -e ${DIM}'Press Enter to return to the log menu...'${NC})"
            fi
        done
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

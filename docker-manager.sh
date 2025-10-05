#!/bin/bash
# Docker Manager Script - Beautiful & Accessible Version
# Optimized for readability and visual clarity

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker daemon is not running"
    exit 1
fi

# Colors - High Contrast
RED='\033[1;91m'
GREEN='\033[1;92m'
YELLOW='\033[1;93m'
BLUE='\033[1;94m'
CYAN='\033[1;96m'
MAGENTA='\033[1;95m'
WHITE='\033[1;97m'
ORANGE='\033[38;5;208m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Symbols - Larger and clearer
CHECK="✓"
CROSS="✗"
WARNING="⚠"
DOCKER="🐳"
ARROW="➜"
DOT="●"

# Cache file
CACHE_FILE="/tmp/docker-manager-cache-$$"
trap "rm -f $CACHE_FILE" EXIT

# Refresh cache
refresh_cache() {
    docker ps -a --format "{{.Names}}|{{.Label \"com.docker.compose.project\"}}|{{.State}}" 2>/dev/null | \
    awk -F'|' '{
        name=$1
        project=$2
        state=$3
        if (project == "" || project == "<no value>") {
            project="__STANDALONE__"
        }
        print project "|" name "|" state
    }' | sort > "$CACHE_FILE"
}

# Find compose projects
find_compose_projects() {
    find "$HOME" -type f \( -name "docker-compose.yml" -o -name "docker-compose.yaml" -o -name "compose.yml" -o -name "compose.yaml" \) 2>/dev/null | \
    while read -r file; do
        dirname "$file"
    done | sort -u
}

# Get project status
get_project_status() {
    local project=$1
    local total=0
    local running=0
    
    while IFS='|' read -r proj name state; do
        if [ "$proj" = "$project" ]; then
            ((total++))
            [ "$state" = "running" ] && ((running++))
        fi
    done < "$CACHE_FILE"
    
    echo "$total|$running"
}

# Beautiful dashboard with better spacing
show_dashboard() {
    clear
    
    # Header with more breathing room
    echo ""
    echo ""
    echo -e "${CYAN}${BOLD}    ╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}    ║                                                                    ║${NC}"
    echo -e "${CYAN}${BOLD}    ║                    ${WHITE}${DOCKER}  DOCKER MANAGER  ${DOCKER}${CYAN}                    ║${NC}"
    echo -e "${CYAN}${BOLD}    ║                                                                    ║${NC}"
    echo -e "${CYAN}${BOLD}    ╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo ""
    
    # Quick stats with larger font effect
    local total=$(wc -l < "$CACHE_FILE")
    local running=$(grep -c "|running$" "$CACHE_FILE")
    local stopped=$((total - running))
    
    echo -e "${WHITE}${BOLD}    SYSTEM STATUS${NC}"
    echo ""
    echo -e "    ${GREEN}${BOLD}●  ${running} Running${NC}     ${RED}${BOLD}●  ${stopped} Stopped${NC}     ${BLUE}${BOLD}●  ${total} Total${NC}"
    echo ""
    echo ""
    
    # Separator
    echo -e "${DIM}    ────────────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo ""
    
    # Get unique projects
    declare -A projects
    declare -A project_paths
    
    # Find compose project directories
    while IFS= read -r path; do
        local proj_name=$(basename "$path")
        project_paths["$proj_name"]="$path"
    done < <(find_compose_projects)
    
    # Get containers grouped by project
    while IFS='|' read -r project name state; do
        if [ -n "$project" ]; then
            if [ -z "${projects[$project]}" ]; then
                projects[$project]="$name:$state"
            else
                projects[$project]="${projects[$project]},$name:$state"
            fi
        fi
    done < "$CACHE_FILE"
    
    # Display sections
    local index=1
    declare -gA MENU_MAP
    
    # Compose Projects Section
    if [ ${#projects[@]} -gt 1 ] || [ -z "${projects[__STANDALONE__]}" ]; then
        echo -e "${YELLOW}${BOLD}    COMPOSE PROJECTS${NC}"
        echo ""
        echo ""
        
        for project in $(printf '%s\n' "${!projects[@]}" | grep -v "^__STANDALONE__$" | sort); do
            local status_info=$(get_project_status "$project")
            IFS='|' read -r total running <<< "$status_info"
            
            # Status indicator with better visual
            if [ "$running" -eq "$total" ] && [ "$running" -gt 0 ]; then
                local indicator="${GREEN}${BOLD}●${NC}"
                local status_text="${GREEN}${BOLD}${running}/${total} running${NC}"
            elif [ "$running" -eq 0 ]; then
                local indicator="${RED}${BOLD}●${NC}"
                local status_text="${RED}${BOLD}0/${total} stopped${NC}"
            else
                local indicator="${YELLOW}${BOLD}●${NC}"
                local status_text="${YELLOW}${BOLD}${running}/${total} partial${NC}"
            fi
            
            # Larger, more spaced layout
            printf "        ${WHITE}${BOLD}[%2d]${NC}  %b  ${WHITE}${BOLD}%-40s${NC}  %b\n" \
                "$index" "$indicator" "$project" "$status_text"
            echo ""
            
            MENU_MAP[$index]="PROJECT|$project|${project_paths[$project]}"
            ((index++))
        done
        
        echo ""
        echo -e "${DIM}    ────────────────────────────────────────────────────────────────────${NC}"
        echo ""
        echo ""
    fi
    
    # Standalone Containers Section
    if [ -n "${projects[__STANDALONE__]}" ]; then
        echo -e "${YELLOW}${BOLD}    STANDALONE CONTAINERS${NC}"
        echo ""
        echo ""
        
        IFS=',' read -ra containers <<< "${projects[__STANDALONE__]}"
        for container_info in "${containers[@]}"; do
            IFS=':' read -r name state <<< "$container_info"
            
            if [ "$state" = "running" ]; then
                local indicator="${GREEN}${BOLD}●${NC}"
                local status_word="${GREEN}${BOLD}running${NC}"
            else
                local indicator="${RED}${BOLD}●${NC}"
                local status_word="${RED}${BOLD}stopped${NC}"
            fi
            
            printf "        ${WHITE}${BOLD}[%2d]${NC}  %b  ${WHITE}${BOLD}%-40s${NC}  %b\n" \
                "$index" "$indicator" "$name" "$status_word"
            echo ""
            
            MENU_MAP[$index]="CONTAINER|$name"
            ((index++))
        done
        
        echo ""
        echo -e "${DIM}    ────────────────────────────────────────────────────────────────────${NC}"
        echo ""
        echo ""
    fi
    
    # Actions menu with more space
    echo -e "${CYAN}${BOLD}    ACTIONS${NC}"
    echo ""
    echo ""
    echo -e "        ${YELLOW}${BOLD}[G]${NC}  ${WHITE}Global Actions${NC}  ${DIM}(clean, prune)${NC}"
    echo ""
    echo -e "        ${YELLOW}${BOLD}[R]${NC}  ${WHITE}Refresh${NC}"
    echo ""
    echo -e "        ${YELLOW}${BOLD}[Q]${NC}  ${WHITE}Quit${NC}"
    echo ""
    echo ""
}

# Container actions menu - redesigned
show_container_actions() {
    local container=$1
    
    while true; do
        clear
        echo ""
        echo ""
        echo -e "${CYAN}${BOLD}    ╔════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}${BOLD}    ║                                                                    ║${NC}"
        echo -e "${CYAN}${BOLD}    ║    CONTAINER: ${WHITE}${container}${NC}"
        echo -e "${CYAN}${BOLD}    ║                                                                    ║${NC}"
        echo -e "${CYAN}${BOLD}    ╚════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo ""
        
        # Get container state
        local state=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
        if [ "$state" = "running" ]; then
            echo -e "    Status:  ${GREEN}${BOLD}●  RUNNING${NC}"
        else
            echo -e "    Status:  ${RED}${BOLD}●  STOPPED${NC}"
        fi
        
        echo ""
        echo ""
        echo -e "${DIM}    ────────────────────────────────────────────────────────────────────${NC}"
        echo ""
        echo ""
        echo -e "${WHITE}${BOLD}    AVAILABLE ACTIONS${NC}"
        echo ""
        echo ""
        echo -e "        ${YELLOW}${BOLD}[1]${NC}  ${WHITE}docker logs${NC}               ${DIM}View container logs${NC}"
        echo ""
        
        if [ "$state" = "running" ]; then
            echo -e "        ${YELLOW}${BOLD}[2]${NC}  ${WHITE}docker restart${NC}            ${DIM}Restart container${NC}"
            echo ""
            echo -e "        ${YELLOW}${BOLD}[3]${NC}  ${WHITE}docker stop${NC}               ${DIM}Stop container${NC}"
            echo ""
        else
            echo -e "        ${YELLOW}${BOLD}[2]${NC}  ${WHITE}docker start${NC}              ${DIM}Start container${NC}"
            echo ""
        fi
        
        echo -e "        ${YELLOW}${BOLD}[4]${NC}  ${RED}docker rm${NC}                 ${DIM}Remove container${NC}"
        echo ""
        echo ""
        echo -e "        ${WHITE}${BOLD}[0]${NC}  ${DIM}Back to main menu${NC}"
        echo ""
        echo ""
        
        read -p "$(echo -e "    ${YELLOW}${BOLD}Select: ${NC}")" action
        
        case $action in
            1)
                view_container_logs "$container"
                ;;
            2)
                if [ "$state" = "running" ]; then
                    echo ""
                    echo -e "    ${YELLOW}Restarting container...${NC}"
                    docker restart "$container" >/dev/null 2>&1
                    echo -e "    ${GREEN}${BOLD}${CHECK}  Container restarted successfully${NC}"
                else
                    echo ""
                    echo -e "    ${YELLOW}Starting container...${NC}"
                    docker start "$container" >/dev/null 2>&1
                    echo -e "    ${GREEN}${BOLD}${CHECK}  Container started successfully${NC}"
                fi
                sleep 2
                refresh_cache
                ;;
            3)
                if [ "$state" = "running" ]; then
                    echo ""
                    echo -e "    ${YELLOW}Stopping container...${NC}"
                    docker stop "$container" >/dev/null 2>&1
                    echo -e "    ${GREEN}${BOLD}${CHECK}  Container stopped successfully${NC}"
                    sleep 2
                    refresh_cache
                fi
                ;;
            4)
                echo ""
                echo ""
                read -p "$(echo -e "    ${RED}${BOLD}Remove '$container'? This cannot be undone. (y/N): ${NC}")" confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    [ "$state" = "running" ] && docker stop "$container" >/dev/null 2>&1
                    docker rm "$container" >/dev/null 2>&1
                    echo ""
                    echo -e "    ${GREEN}${BOLD}${CHECK}  Container removed${NC}"
                    sleep 2
                    refresh_cache
                    return
                fi
                ;;
            0)
                return
                ;;
        esac
    done
}

# Project actions menu - redesigned
show_project_actions() {
    local project=$1
    local project_path=$2
    
    # Find path if not provided
    if [ -z "$project_path" ] || [ ! -d "$project_path" ]; then
        project_path=$(find_compose_projects | grep -m1 "/${project}$")
    fi
    
    if [ -z "$project_path" ] || [ ! -d "$project_path" ]; then
        echo -e "    ${RED}${CROSS} Project directory not found${NC}"
        sleep 2
        return
    fi
    
    while true; do
        clear
        echo ""
        echo ""
        echo -e "${CYAN}${BOLD}    ╔════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}${BOLD}    ║                                                                    ║${NC}"
        echo -e "${CYAN}${BOLD}    ║    PROJECT: ${WHITE}${project}${NC}"
        echo -e "${CYAN}${BOLD}    ║                                                                    ║${NC}"
        echo -e "${CYAN}${BOLD}    ╚════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo ""
        
        local status_info=$(get_project_status "$project")
        IFS='|' read -r total running <<< "$status_info"
        
        echo -e "    Path:    ${DIM}${project_path}${NC}"
        echo ""
        
        if [ "$running" -eq "$total" ] && [ "$running" -gt 0 ]; then
            echo -e "    Status:  ${GREEN}${BOLD}●  ${running}/${total} RUNNING${NC}"
        elif [ "$running" -eq 0 ]; then
            echo -e "    Status:  ${RED}${BOLD}●  ${running}/${total} STOPPED${NC}"
        else
            echo -e "    Status:  ${YELLOW}${BOLD}●  ${running}/${total} PARTIAL${NC}"
        fi
        
        echo ""
        echo ""
        echo -e "${DIM}    ────────────────────────────────────────────────────────────────────${NC}"
        echo ""
        echo ""
        echo -e "${WHITE}${BOLD}    AVAILABLE ACTIONS${NC}"
        echo ""
        echo ""
        echo -e "        ${YELLOW}${BOLD}[1]${NC}  ${WHITE}docker compose logs${NC}                  ${DIM}View logs${NC}"
        echo ""
        echo -e "        ${YELLOW}${BOLD}[2]${NC}  ${WHITE}docker compose pull + up -d${NC}         ${GREEN}${DIM}Update & recreate${NC}"
        echo ""
        echo -e "        ${YELLOW}${BOLD}[3]${NC}  ${WHITE}docker compose up -d${NC}                ${DIM}Start project${NC}"
        echo ""
        echo -e "        ${YELLOW}${BOLD}[4]${NC}  ${WHITE}docker compose down${NC}                 ${RED}${DIM}Stop & remove${NC}"
        echo ""
        echo -e "        ${YELLOW}${BOLD}[5]${NC}  ${WHITE}docker compose restart${NC}              ${DIM}Restart project${NC}"
        echo ""
        echo -e "        ${YELLOW}${BOLD}[6]${NC}  ${WHITE}docker compose pull${NC}                 ${DIM}Pull images only${NC}"
        echo ""
        echo ""
        echo -e "        ${WHITE}${BOLD}[0]${NC}  ${DIM}Back to main menu${NC}"
        echo ""
        echo ""
        
        read -p "$(echo -e "    ${YELLOW}${BOLD}Select: ${NC}")" action
        
        cd "$project_path" || continue
        
        case $action in
            1)
                view_project_logs "$project_path"
                ;;
            2)
                echo ""
                echo ""
                read -p "$(echo -e "    ${YELLOW}${BOLD}Update project '$project'? (y/N): ${NC}")" confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    echo ""
                    echo -e "    ${CYAN}Step 1/2: Pulling latest images...${NC}"
                    docker compose pull
                    echo ""
                    echo -e "    ${CYAN}Step 2/2: Recreating containers...${NC}"
                    docker compose up -d --remove-orphans
                    echo ""
                    echo -e "    ${GREEN}${BOLD}${CHECK}  Project updated successfully${NC}"
                    sleep 3
                    refresh_cache
                fi
                ;;
            3)
                echo ""
                echo -e "    ${YELLOW}Starting project...${NC}"
                docker compose up -d
                echo ""
                echo -e "    ${GREEN}${BOLD}${CHECK}  Project started${NC}"
                sleep 2
                refresh_cache
                ;;
            4)
                echo ""
                echo ""
                read -p "$(echo -e "    ${RED}${BOLD}Stop and remove '$project'? (y/N): ${NC}")" confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    echo ""
                    echo -e "    ${YELLOW}Stopping project...${NC}"
                    docker compose down
                    echo ""
                    echo -e "    ${GREEN}${BOLD}${CHECK}  Project stopped${NC}"
                    sleep 2
                    refresh_cache
                fi
                ;;
            5)
                echo ""
                echo -e "    ${YELLOW}Restarting project...${NC}"
                docker compose restart
                echo ""
                echo -e "    ${GREEN}${BOLD}${CHECK}  Project restarted${NC}"
                sleep 2
                refresh_cache
                ;;
            6)
                echo ""
                echo -e "    ${YELLOW}Pulling latest images...${NC}"
                docker compose pull
                echo ""
                echo -e "    ${GREEN}${BOLD}${CHECK}  Images pulled${NC}"
                echo -e "    ${DIM}Run 'docker compose up -d' to apply changes${NC}"
                sleep 3
                ;;
            0)
                return
                ;;
        esac
    done
}

# View container logs
view_container_logs() {
    local container=$1
    
    while true; do
        clear
        echo ""
        echo ""
        echo -e "${CYAN}${BOLD}    LOGS: ${WHITE}${container}${NC}"
        echo ""
        echo -e "${DIM}    ════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo ""
        echo -e "${WHITE}${BOLD}    SELECT TIME RANGE${NC}"
        echo ""
        echo ""
        echo -e "        ${YELLOW}${BOLD}[1]${NC}  ${WHITE}Last hour${NC}"
        echo ""
        echo -e "        ${YELLOW}${BOLD}[2]${NC}  ${WHITE}Today${NC}"
        echo ""
        echo -e "        ${YELLOW}${BOLD}[3]${NC}  ${WHITE}Last 100 lines${NC}"
        echo ""
        echo -e "        ${YELLOW}${BOLD}[4]${NC}  ${WHITE}Follow live${NC}  ${DIM}(Ctrl+C to stop)${NC}"
        echo ""
        echo ""
        echo -e "        ${WHITE}${BOLD}[0]${NC}  ${DIM}Back${NC}"
        echo ""
        echo ""
        
        read -p "$(echo -e "    ${YELLOW}${BOLD}Select: ${NC}")" choice
        
        case $choice in
            1)
                clear
                echo ""
                echo -e "${BLUE}${BOLD}    Logs from last hour:${NC}"
                echo ""
                docker logs --since 1h "$container" 2>&1 | colorize_logs | less -R +G
                ;;
            2)
                clear
                echo ""
                echo -e "${BLUE}${BOLD}    Logs from today:${NC}"
                echo ""
                docker logs --since "$(date '+%Y-%m-%d')T00:00:00" "$container" 2>&1 | colorize_logs | less -R +G
                ;;
            3)
                clear
                echo ""
                echo -e "${BLUE}${BOLD}    Last 100 lines:${NC}"
                echo ""
                docker logs --tail 100 "$container" 2>&1 | colorize_logs | less -R +G
                ;;
            4)
                clear
                echo ""
                echo -e "${BLUE}${BOLD}    Following live logs (Ctrl+C to stop):${NC}"
                echo ""
                docker logs -f --tail 50 "$container" 2>&1 | colorize_logs
                ;;
            0)
                return
                ;;
        esac
    done
}

# View project logs
view_project_logs() {
    local project_path=$1
    
    cd "$project_path" || return
    
    while true; do
        clear
        echo ""
        echo ""
        echo -e "${CYAN}${BOLD}    PROJECT LOGS: ${WHITE}$(basename "$project_path")${NC}"
        echo ""
        echo -e "${DIM}    ════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo ""
        echo -e "${WHITE}${BOLD}    SELECT TIME RANGE${NC}"
        echo ""
        echo ""
        echo -e "        ${YELLOW}${BOLD}[1]${NC}  ${WHITE}Last hour${NC}"
        echo ""
        echo -e "        ${YELLOW}${BOLD}[2]${NC}  ${WHITE}Today${NC}"
        echo ""
        echo -e "        ${YELLOW}${BOLD}[3]${NC}  ${WHITE}Last 100 lines${NC}"
        echo ""
        echo -e "        ${YELLOW}${BOLD}[4]${NC}  ${WHITE}Follow live${NC}  ${DIM}(Ctrl+C to stop)${NC}"
        echo ""
        echo ""
        echo -e "        ${WHITE}${BOLD}[0]${NC}  ${DIM}Back${NC}"
        echo ""
        echo ""
        
        read -p "$(echo -e "    ${YELLOW}${BOLD}Select: ${NC}")" choice
        
        case $choice in
            1)
                clear
                echo ""
                echo -e "${BLUE}${BOLD}    Logs from last hour:${NC}"
                echo ""
                docker compose logs --since 1h 2>&1 | colorize_logs | less -R +G
                ;;
            2)
                clear
                echo ""
                echo -e "${BLUE}${BOLD}    Logs from today:${NC}"
                echo ""
                docker compose logs --since "$(date '+%Y-%m-%d')T00:00:00" 2>&1 | colorize_logs | less -R +G
                ;;
            3)
                clear
                echo ""
                echo -e "${BLUE}${BOLD}    Last 100 lines:${NC}"
                echo ""
                docker compose logs --tail 100 2>&1 | colorize_logs | less -R +G
                ;;
            4)
                clear
                echo ""
                echo -e "${BLUE}${BOLD}    Following live logs (Ctrl+C to stop):${NC}"
                echo ""
                docker compose logs -f --tail 50 2>&1 | colorize_logs
                ;;
            0)
                return
                ;;
        esac
    done
}

# Colorize logs
colorize_logs() {
    sed -E "s/\b(ERROR|error|Error|FAIL|fail|Fail|FAILED|failed|Failed|FATAL|fatal|Fatal|PANIC|panic|Panic)\b/$(printf '\033[1;91m')&$(printf '\033[0m')/g" | \
    sed -E "s/\b(WARNING|warning|Warning|WARN|warn|Warn)\b/$(printf '\033[1;93m')&$(printf '\033[0m')/g" | \
    sed -E "s/\b(INFO|info|Info)\b/$(printf '\033[1;94m')&$(printf '\033[0m')/g" | \
    sed -E "s/\b([4-5][0-9]{2})\b/$(printf '\033[1;91m')&$(printf '\033[0m')/g"
}

# Global actions - Clean Docker
clean_docker() {
    clear
    echo ""
    echo ""
    echo -e "${CYAN}${BOLD}    ╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}    ║                                                                    ║${NC}"
    echo -e "${CYAN}${BOLD}    ║    CLEAN DOCKER SYSTEM${NC}"
    echo -e "${CYAN}${BOLD}    ║                                                                    ║${NC}"
    echo -e "${CYAN}${BOLD}    ╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo ""
    echo -e "${WHITE}${BOLD}    CURRENT DISK USAGE${NC}"
    echo ""
    docker system df | sed 's/^/    /'
    echo ""
    echo ""
    echo -e "${YELLOW}${BOLD}    This will remove:${NC}"
    echo ""
    echo -e "        ${DOT}  All stopped containers"
    echo -e "        ${DOT}  All unused networks"
    echo -e "        ${DOT}  All dangling images"
    echo -e "        ${DOT}  All dangling build cache"
    echo ""
    echo ""
    echo -e "    ${GREEN}${BOLD}Running containers and named volumes are safe.${NC}"
    echo ""
    echo ""
    read -p "$(echo -e "    ${YELLOW}${BOLD}Proceed with cleanup? (y/N): ${NC}")" confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "    ${YELLOW}Running cleanup...${NC}"
        docker system prune -f 2>&1 | sed 's/^/    /'
        echo ""
        echo -e "    ${GREEN}${BOLD}${CHECK}  Cleanup complete${NC}"
        
        # Check for unused volumes
        local unused_volumes=$(docker volume ls -qf dangling=true | wc -l)
        if [ "$unused_volumes" -gt 0 ]; then
            echo ""
            echo ""
            echo -e "    ${ORANGE}${WARNING}  Found ${unused_volumes} unused volumes${NC}"
            echo ""
            read -p "$(echo -e "    ${RED}${BOLD}Remove unused volumes? (y/N): ${NC}")" vol_confirm
            if [[ "$vol_confirm" =~ ^[Yy]$ ]]; then
                docker volume prune -f 2>&1 | sed 's/^/    /'
                echo ""
                echo -e "    ${GREEN}${BOLD}${CHECK}  Unused volumes removed${NC}"
            fi
        fi
        
        echo ""
        echo ""
        echo -e "${WHITE}${BOLD}    DISK USAGE AFTER CLEANUP${NC}"
        echo ""
        docker system df | sed 's/^/    /'
    fi
    
    echo ""
    echo ""
    read -p "$(echo -e "    ${DIM}Press Enter to continue...${NC}")"
    refresh_cache
}

# Main function
main() {
    refresh_cache
    
    while true; do
        show_dashboard
        
        read -p "$(echo -e "    ${YELLOW}${BOLD}Select: ${NC}")" choice
        
        case ${choice,,} in
            q)
                echo ""
                echo ""
                echo -e "    ${GREEN}${BOLD}Goodbye! ${DOCKER}${NC}"
                echo ""
                echo ""
                exit 0
                ;;
            r)
                refresh_cache
                ;;
            g)
                clean_docker
                ;;
            [0-9]*)
                if [ -n "${MENU_MAP[$choice]}" ]; then
                    IFS='|' read -r type name path <<< "${MENU_MAP[$choice]}"
                    
                    if [ "$type" = "PROJECT" ]; then
                        show_project_actions "$name" "$path"
                    elif [ "$type" = "CONTAINER" ]; then
                        show_container_actions "$name"
                    fi
                    refresh_cache
                fi
                ;;
        esac
    done
}

# Run main
main

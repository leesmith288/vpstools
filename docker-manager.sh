#!/bin/bash
# Docker Manager Script - Optimized Version
# Fast, minimal display with two-level menu system
# Compatible with Docker Compose V2

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ Docker daemon is not running or you don't have permission"
    exit 1
fi

# Colors
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

# Symbols
CHECK="✓"
CROSS="✗"
WARNING="⚠"
DOCKER="🐳"

# Cache file for container list
CACHE_FILE="/tmp/docker-manager-cache-$$"
trap "rm -f $CACHE_FILE" EXIT

# Function to get all containers and projects (cached)
refresh_cache() {
    {
        # Get compose projects from running containers
        docker ps -a --format "{{.Names}}|{{.Label \"com.docker.compose.project\"}}|{{.State}}" 2>/dev/null | \
        awk -F'|' '{
            name=$1
            project=$2
            state=$3
            if (project == "" || project == "<no value>") {
                project="__STANDALONE__"
            }
            print project "|" name "|" state
        }' | sort
    } > "$CACHE_FILE"
}

# Function to find docker-compose project directories
find_compose_projects() {
    find "$HOME" -type f \( -name "docker-compose.yml" -o -name "docker-compose.yaml" -o -name "compose.yml" -o -name "compose.yaml" \) 2>/dev/null | \
    while read -r file; do
        dirname "$file"
    done | sort -u
}

# Function to get project containers count and status
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

# Minimal dashboard display
show_dashboard() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}                 ${DOCKER} DOCKER MANAGER ${DOCKER}                          ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Quick stats
    local total=$(wc -l < "$CACHE_FILE")
    local running=$(grep -c "|running$" "$CACHE_FILE")
    local stopped=$((total - running))
    
    echo -e "${WHITE}  Total: ${total} containers  ${GREEN}●${NC} ${running} running  ${RED}●${NC} ${stopped} stopped${NC}"
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo ""
    
    # Get unique projects
    declare -A projects
    declare -A project_paths
    
    # First, find all compose project directories
    while IFS= read -r path; do
        local proj_name=$(basename "$path")
        project_paths["$proj_name"]="$path"
    done < <(find_compose_projects)
    
    # Then get running containers grouped by project
    while IFS='|' read -r project name state; do
        if [ -n "$project" ]; then
            if [ -z "${projects[$project]}" ]; then
                projects[$project]="$name:$state"
            else
                projects[$project]="${projects[$project]},$name:$state"
            fi
        fi
    done < "$CACHE_FILE"
    
    # Display compose projects
    local index=1
    declare -gA MENU_MAP  # Global associative array for menu mapping
    
    if [ ${#projects[@]} -gt 1 ] || [ -z "${projects[__STANDALONE__]}" ]; then
        echo -e "${YELLOW}${BOLD}DOCKER COMPOSE PROJECTS:${NC}"
        echo ""
        
        for project in $(printf '%s\n' "${!projects[@]}" | grep -v "^__STANDALONE__$" | sort); do
            local status_info=$(get_project_status "$project")
            IFS='|' read -r total running <<< "$status_info"
            
            # Status indicator
            if [ "$running" -eq "$total" ] && [ "$running" -gt 0 ]; then
                local indicator="${GREEN}●${NC}"
                local status_text="${GREEN}${running}/${total}${NC}"
            elif [ "$running" -eq 0 ]; then
                local indicator="${RED}●${NC}"
                local status_text="${RED}0/${total}${NC}"
            else
                local indicator="${YELLOW}●${NC}"
                local status_text="${YELLOW}${running}/${total}${NC}"
            fi
            
            printf "  ${WHITE}%2d)${NC} %b %-35s %b\n" \
                "$index" "$indicator" "$project" "$status_text"
            
            MENU_MAP[$index]="PROJECT|$project|${project_paths[$project]}"
            ((index++))
        done
        echo ""
    fi
    
    # Display standalone containers
    if [ -n "${projects[__STANDALONE__]}" ]; then
        echo -e "${YELLOW}${BOLD}STANDALONE CONTAINERS:${NC}"
        echo ""
        
        IFS=',' read -ra containers <<< "${projects[__STANDALONE__]}"
        for container_info in "${containers[@]}"; do
            IFS=':' read -r name state <<< "$container_info"
            
            if [ "$state" = "running" ]; then
                local indicator="${GREEN}●${NC}"
            else
                local indicator="${RED}●${NC}"
            fi
            
            printf "  ${WHITE}%2d)${NC} %b %s\n" "$index" "$indicator" "$name"
            
            MENU_MAP[$index]="CONTAINER|$name"
            ((index++))
        done
        echo ""
    fi
    
    echo -e "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -e "  ${YELLOW}G)${NC} Global actions (clean, prune)"
    echo -e "  ${YELLOW}R)${NC} Refresh"
    echo -e "  ${YELLOW}Q)${NC} Quit"
    echo ""
}

# Container actions menu
show_container_actions() {
    local container=$1
    
    while true; do
        clear
        echo ""
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${WHITE}${BOLD}  Container: ${container}${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Get container state
        local state=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
        if [ "$state" = "running" ]; then
            echo -e "  Status: ${GREEN}● Running${NC}"
        else
            echo -e "  Status: ${RED}● Stopped${NC}"
        fi
        echo ""
        echo -e "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
        echo ""
        echo -e "${WHITE}${BOLD}ACTIONS:${NC}"
        echo ""
        echo -e "  ${YELLOW}1)${NC} docker logs - View logs"
        
        if [ "$state" = "running" ]; then
            echo -e "  ${YELLOW}2)${NC} docker restart - Restart container"
            echo -e "  ${YELLOW}3)${NC} docker stop - Stop container"
        else
            echo -e "  ${YELLOW}2)${NC} docker start - Start container"
        fi
        
        echo -e "  ${YELLOW}4)${NC} docker rm - Remove container"
        echo ""
        echo -e "  ${WHITE}0)${NC} Back to main menu"
        echo ""
        
        read -p "$(echo -e ${YELLOW}${BOLD}'Select action: '${NC})" action
        
        case $action in
            1)
                view_container_logs "$container"
                ;;
            2)
                if [ "$state" = "running" ]; then
                    echo ""
                    echo -e "${YELLOW}Restarting container...${NC}"
                    docker restart "$container"
                    echo -e "${GREEN}${CHECK} Container restarted${NC}"
                else
                    echo ""
                    echo -e "${YELLOW}Starting container...${NC}"
                    docker start "$container"
                    echo -e "${GREEN}${CHECK} Container started${NC}"
                fi
                sleep 2
                refresh_cache
                ;;
            3)
                if [ "$state" = "running" ]; then
                    echo ""
                    echo -e "${YELLOW}Stopping container...${NC}"
                    docker stop "$container"
                    echo -e "${GREEN}${CHECK} Container stopped${NC}"
                    sleep 2
                    refresh_cache
                fi
                ;;
            4)
                echo ""
                read -p "$(echo -e ${RED}${BOLD}"Remove container '$container'? (y/N): "${NC})" confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    [ "$state" = "running" ] && docker stop "$container"
                    docker rm "$container"
                    echo -e "${GREEN}${CHECK} Container removed${NC}"
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

# Project actions menu
show_project_actions() {
    local project=$1
    local project_path=$2
    
    # If path not found, try to find it
    if [ -z "$project_path" ] || [ ! -d "$project_path" ]; then
        project_path=$(find_compose_projects | grep -m1 "/${project}$")
    fi
    
    if [ -z "$project_path" ] || [ ! -d "$project_path" ]; then
        echo -e "${RED}${CROSS} Project directory not found${NC}"
        sleep 2
        return
    fi
    
    while true; do
        clear
        echo ""
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${WHITE}${BOLD}  Project: ${project}${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        local status_info=$(get_project_status "$project")
        IFS='|' read -r total running <<< "$status_info"
        
        echo -e "  Path: ${DIM}${project_path}${NC}"
        echo -e "  Status: ${running}/${total} containers running"
        echo ""
        echo -e "${CYAN}────────────────────────────────────────────────────────────────────${NC}"
        echo ""
        echo -e "${WHITE}${BOLD}ACTIONS:${NC}"
        echo ""
        echo -e "  ${YELLOW}1)${NC} docker compose logs"
        echo -e "  ${YELLOW}2)${NC} docker compose pull + up -d ${DIM}(update & recreate)${NC}"
        echo -e "  ${YELLOW}3)${NC} docker compose up -d ${DIM}(start/create)${NC}"
        echo -e "  ${YELLOW}4)${NC} docker compose down ${DIM}(stop & remove)${NC}"
        echo -e "  ${YELLOW}5)${NC} docker compose restart"
        echo -e "  ${YELLOW}6)${NC} docker compose pull ${DIM}(pull images only)${NC}"
        echo ""
        echo -e "  ${WHITE}0)${NC} Back to main menu"
        echo ""
        
        read -p "$(echo -e ${YELLOW}${BOLD}'Select action: '${NC})" action
        
        cd "$project_path" || continue
        
        case $action in
            1)
                view_project_logs "$project_path"
                ;;
            2)
                echo ""
                echo -e "${CYAN}${BOLD}Full Update: Pull + Recreate${NC}"
                echo ""
                read -p "$(echo -e ${YELLOW}${BOLD}"Update project '$project'? (y/N): "${NC})" confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    echo ""
                    echo -e "${YELLOW}Pulling latest images...${NC}"
                    docker compose pull
                    echo ""
                    echo -e "${YELLOW}Recreating containers...${NC}"
                    docker compose up -d --remove-orphans
                    echo ""
                    echo -e "${GREEN}${CHECK} Project updated${NC}"
                    sleep 2
                    refresh_cache
                fi
                ;;
            3)
                echo ""
                echo -e "${YELLOW}Starting project...${NC}"
                docker compose up -d
                echo -e "${GREEN}${CHECK} Project started${NC}"
                sleep 2
                refresh_cache
                ;;
            4)
                echo ""
                read -p "$(echo -e ${RED}${BOLD}"Stop and remove project '$project'? (y/N): "${NC})" confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    echo ""
                    echo -e "${YELLOW}Stopping project...${NC}"
                    docker compose down
                    echo -e "${GREEN}${CHECK} Project stopped${NC}"
                    sleep 2
                    refresh_cache
                fi
                ;;
            5)
                echo ""
                echo -e "${YELLOW}Restarting project...${NC}"
                docker compose restart
                echo -e "${GREEN}${CHECK} Project restarted${NC}"
                sleep 2
                refresh_cache
                ;;
            6)
                echo ""
                echo -e "${YELLOW}Pulling latest images...${NC}"
                docker compose pull
                echo -e "${GREEN}${CHECK} Images pulled${NC}"
                echo -e "${DIM}Run 'docker compose up -d' to apply changes${NC}"
                sleep 3
                ;;
            0)
                return
                ;;
        esac
    done
}

# View container logs with time range selection
view_container_logs() {
    local container=$1
    
    while true; do
        clear
        echo -e "${CYAN}${BOLD}Logs: ${container}${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${WHITE}${BOLD}Select time range:${NC}"
        echo ""
        echo -e "  ${YELLOW}1)${NC} Last hour"
        echo -e "  ${YELLOW}2)${NC} Today"
        echo -e "  ${YELLOW}3)${NC} Last 100 lines"
        echo -e "  ${YELLOW}4)${NC} Follow live (Ctrl+C to stop)"
        echo ""
        echo -e "  ${WHITE}0)${NC} Back"
        echo ""
        
        read -p "$(echo -e ${YELLOW}${BOLD}'Select: '${NC})" choice
        
        case $choice in
            1)
                clear
                echo -e "${BLUE}Logs from last hour:${NC}"
                echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
                echo ""
                docker logs --since 1h "$container" 2>&1 | colorize_logs | less -R
                ;;
            2)
                clear
                echo -e "${BLUE}Logs from today:${NC}"
                echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
                echo ""
                docker logs --since "$(date '+%Y-%m-%d')T00:00:00" "$container" 2>&1 | colorize_logs | less -R
                ;;
            3)
                clear
                echo -e "${BLUE}Last 100 lines:${NC}"
                echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
                echo ""
                docker logs --tail 100 "$container" 2>&1 | colorize_logs | less -R
                ;;
            4)
                clear
                echo -e "${BLUE}Following live logs (Ctrl+C to stop):${NC}"
                echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
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
        echo -e "${CYAN}${BOLD}Project Logs: $(basename "$project_path")${NC}"
        echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${WHITE}${BOLD}Select time range:${NC}"
        echo ""
        echo -e "  ${YELLOW}1)${NC} Last hour"
        echo -e "  ${YELLOW}2)${NC} Today"
        echo -e "  ${YELLOW}3)${NC} Last 100 lines"
        echo -e "  ${YELLOW}4)${NC} Follow live (Ctrl+C to stop)"
        echo ""
        echo -e "  ${WHITE}0)${NC} Back"
        echo ""
        
        read -p "$(echo -e ${YELLOW}${BOLD}'Select: '${NC})" choice
        
        case $choice in
            1)
                clear
                echo -e "${BLUE}Logs from last hour:${NC}"
                echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
                echo ""
                docker compose logs --since 1h 2>&1 | colorize_logs | less -R
                ;;
            2)
                clear
                echo -e "${BLUE}Logs from today:${NC}"
                echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
                echo ""
                docker compose logs --since "$(date '+%Y-%m-%d')T00:00:00" 2>&1 | colorize_logs | less -R
                ;;
            3)
                clear
                echo -e "${BLUE}Last 100 lines:${NC}"
                echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
                echo ""
                docker compose logs --tail 100 2>&1 | colorize_logs | less -R
                ;;
            4)
                clear
                echo -e "${BLUE}Following live logs (Ctrl+C to stop):${NC}"
                echo -e "${DIM}════════════════════════════════════════════════════════════════════${NC}"
                echo ""
                docker compose logs -f --tail 50 2>&1 | colorize_logs
                ;;
            0)
                return
                ;;
        esac
    done
}

# Colorize log output
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
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}  CLEAN DOCKER SYSTEM${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}${BOLD}Current disk usage:${NC}"
    echo ""
    docker system df
    echo ""
    echo -e "${YELLOW}${BOLD}This will remove:${NC}"
    echo -e "  • All stopped containers"
    echo -e "  • All unused networks"
    echo -e "  • All dangling images"
    echo -e "  • All dangling build cache"
    echo ""
    echo -e "${GREEN}Running containers and named volumes will NOT be affected.${NC}"
    echo ""
    read -p "$(echo -e ${YELLOW}${BOLD}'Proceed with cleanup? (y/N): '${NC})" confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${YELLOW}Running cleanup...${NC}"
        docker system prune -f
        echo ""
        echo -e "${GREEN}${CHECK} Cleanup complete${NC}"
        
        # Check for unused volumes
        local unused_volumes=$(docker volume ls -qf dangling=true | wc -l)
        if [ "$unused_volumes" -gt 0 ]; then
            echo ""
            echo -e "${ORANGE}${WARNING} Found ${unused_volumes} unused volumes${NC}"
            read -p "$(echo -e ${RED}${BOLD}'Remove unused volumes? (y/N): '${NC})" vol_confirm
            if [[ "$vol_confirm" =~ ^[Yy]$ ]]; then
                docker volume prune -f
                echo -e "${GREEN}${CHECK} Unused volumes removed${NC}"
            fi
        fi
        
        echo ""
        echo -e "${WHITE}${BOLD}Disk usage after cleanup:${NC}"
        echo ""
        docker system df
    fi
    
    echo ""
    read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
    refresh_cache
}

# Main function
main() {
    # Initial cache refresh in background
    refresh_cache
    
    while true; do
        show_dashboard
        
        read -p "$(echo -e ${YELLOW}${BOLD}'Select [1-N, G, R, Q]: '${NC})" choice
        
        case ${choice,,} in
            q)
                echo ""
                echo -e "${GREEN}${BOLD}Goodbye! 🐳${NC}"
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
                else
                    echo -e "${RED}Invalid selection${NC}"
                    sleep 1
                fi
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

# Run main
main

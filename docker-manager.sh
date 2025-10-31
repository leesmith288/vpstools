#!/bin/bash
# Docker Manager Script - Beautiful & Safe Version
# Streamlined with single deep cleanup and immediate log viewing
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
# Symbols
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
        if (project "" || project "<no value>") {
            project="__STANDALONE__"
        }
        print project "|" name "|" state
    }' | sort > "$CACHE_FILE"
}
# Find compose projects
find_compose_projects() {
    # First, try to find all compose files in home
    local compose_dirs=$(find "$HOME" -type f \( -name "docker-compose.yml" -o -name "docker-compose.yaml" -o -name "compose.yml" -o -name "compose.yaml" \) 2>/dev/null | \
    while read -r file; do
        dirname "$file"
    done | sort -u)
    # Also check common Docker locations
    for dir in /opt /srv /var/lib; do
        if [ -d "$dir" ]; then
            find "$dir" -maxdepth 3 -type f \( -name "docker-compose.yml" -o -name "docker-compose.yaml" -o -name "compose.yml" -o -name "compose.yaml" \) 2>/dev/null | \
            while read -r file; do
                dirname "$file"
            done
        fi
    done 2>/dev/null
    echo "$compose_dirs" | sort -u
}
# FIXED: Much better fuzzy matching for project paths
find_project_path() {
    local project_name=$1
    local found_path=""
    local all_paths=$(find_compose_projects)
    # Debug output
    echo -e "    ${DIM}Looking for project: $project_name${NC}" >&2
    # Try exact match first
    found_path=$(echo "$all_paths" | grep -m1 "/${project_name}$")
    if [ -n "$found_path" ]; then
        echo "$found_path"
        return
    fi
    # Try case-insensitive exact match
    found_path=$(echo "$all_paths" | grep -i -m1 "/${project_name}$")
    if [ -n "$found_path" ]; then
        echo "$found_path"
        return
    fi
    # IMPORTANT FIX: Handle common abbreviations and variations
    # Convert "database" to "db" and vice versa
    local variations=()
    variations+=("$project_name")
    variations+=("$(echo "$project_name" | sed 's/database/db/g')")
    variations+=("$(echo "$project_name" | sed 's/db/database/g')")
    variations+=("$(echo "$project_name" | tr '_' '-')")
    variations+=("$(echo "$project_name" | tr '-' '_')")
    variations+=("$(echo "$project_name" | sed 's/-database$/-db/g')")
    variations+=("$(echo "$project_name" | sed 's/_database$/_db/g')")
    variations+=("$(echo "$project_name" | sed 's/-db$/-database/g')")
    variations+=("$(echo "$project_name" | sed 's/_db$/_database/g')")
    # Try each variation
    for variant in "${variations[@]}"; do
        # Try exact match with variant
        found_path=$(echo "$all_paths" | grep -i -m1 "/${variant}$")
        if [ -n "$found_path" ]; then
            echo "$found_path"
            return
        fi
        # Try partial match with variant (beginning of path component)
        found_path=$(echo "$all_paths" | grep -i -m1 "/${variant}")
        if [ -n "$found_path" ]; then
            echo "$found_path"
            return
        fi
    done
    # Last resort: try to match any part of the project name
    # Split by common separators and try to match the main part
    local main_part=$(echo "$project_name" | sed -E 's/[-_](db|database|api|app|service|server|client)$//i')
    if [ -n "$main_part" ] && [ "$main_part" != "$project_name" ]; then
        found_path=$(echo "$all_paths" | grep -i -m1 "/${main_part}")
        if [ -n "$found_path" ]; then
            echo "$found_path"
            return
        fi
    fi
    # If still not found, return empty
    echo ""
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
# Press Enter to continue helper
press_enter() {
    echo ""
    echo ""
    read -p "$(echo -e "    ${DIM}Press Enter to continue...${NC}")"
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
    # Separator (removed status section)
    echo -e "${DIM}    ────────────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo ""
    # Get unique projects and build path mappings
    declare -A projects
    declare -A project_paths
    # Build comprehensive project-to-path mapping
    while IFS= read -r path; do
        if [ -n "$path" ] && [ -d "$path" ]; then
            local dir_name=$(basename "$path")
            project_paths["$dir_name"]="$path"
            # IMPORTANT: Also map common variations
            # Handle lobe-chat-db -> lobe-chat-database mapping
            case "$dir_name" in
                *-db)
                    local alt_name="${dir_name%-db}-database"
                    project_paths["$alt_name"]="$path"
                    ;;
                *_db)
                    local alt_name="${dir_name%_db}_database"
                    project_paths["$alt_name"]="$path"
                    ;;
                *-database)
                    local alt_name="${dir_name%-database}-db"
                    project_paths["$alt_name"]="$path"
                    ;;
                *_database)
                    local alt_name="${dir_name%_database}_db"
                    project_paths["$alt_name"]="$path"
                    ;;
            esac
        fi
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
            # Try to find the path using our mapping first, then fuzzy search
            local proj_path="${project_paths[$project]}"
            if [ -z "$proj_path" ] || [ ! -d "$proj_path" ]; then
                proj_path=$(find_project_path "$project" 2>/dev/null)
            fi
            MENU_MAP[$index]="PROJECT|$project|$proj_path"
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
    echo -e "        ${YELLOW}${BOLD}[C]${NC}  ${WHITE}Clean System${NC}  ${DIM}(remove unused resources)${NC}"
    echo ""
    echo -e "        ${YELLOW}${BOLD}[R]${NC}  ${WHITE}Refresh${NC}"
    echo ""
    echo -e "        ${YELLOW}${BOLD}[Q]${NC}  ${WHITE}Quit${NC}"
    echo ""
    echo ""
}
# Container actions menu
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
        # Check if container still exists
        if ! docker inspect "$container" &>/dev/null; then
            echo -e "    ${RED}${CROSS} Container no longer exists${NC}"
            press_enter
            return
        fi
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
        echo -e "        ${YELLOW}${BOLD}[1]${NC}  ${WHITE}View logs${NC}                 ${DIM}View container logs${NC}"
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
                    if docker restart "$container" &>/dev/null; then
                        echo -e "    ${GREEN}${BOLD}${CHECK}  Container restarted successfully${NC}"
                    else
                        echo -e "    ${RED}${BOLD}${CROSS}  Failed to restart container${NC}"
                    fi
                else
                    echo ""
                    echo -e "    ${YELLOW}Starting container...${NC}"
                    if docker start "$container" &>/dev/null; then
                        echo -e "    ${GREEN}${BOLD}${CHECK}  Container started successfully${NC}"
                    else
                        echo -e "    ${RED}${BOLD}${CROSS}  Failed to start container${NC}"
                    fi
                fi
                sleep 2
                refresh_cache
                ;;
            3)
                if [ "$state" = "running" ]; then
                    echo ""
                    echo -e "    ${YELLOW}Stopping container...${NC}"
                    if docker stop "$container" &>/dev/null; then
                        echo -e "    ${GREEN}${BOLD}${CHECK}  Container stopped successfully${NC}"
                    else
                        echo -e "    ${RED}${BOLD}${CROSS}  Failed to stop container${NC}"
                    fi
                    sleep 2
                    refresh_cache
                fi
                ;;
            4)
                echo ""
                echo ""
                read -p "$(echo -e "    ${RED}${BOLD}Remove '$container'? This cannot be undone. (y/N): ${NC}")" confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    [ "$state" = "running" ] && docker stop "$container" &>/dev/null
                    if docker rm "$container" &>/dev/null; then
                        echo ""
                        echo -e "    ${GREEN}${BOLD}${CHECK}  Container removed${NC}"
                        sleep 2
                        refresh_cache
                        return
                    else
                        echo ""
                        echo -e "    ${RED}${BOLD}${CROSS}  Failed to remove container${NC}"
                        sleep 2
                    fi
                fi
                ;;
            0)
                return
                ;;
            *)
                ;;
        esac
    done
}
# Project actions menu - FIXED
show_project_actions() {
    local project=$1
    local project_path=$2
    # Better path finding with cleaner output
    if [ -z "$project_path" ] || [ ! -d "$project_path" ]; then
        project_path=$(find_project_path "$project" 2>/dev/null)
        if [ -z "$project_path" ] || [ ! -d "$project_path" ]; then
            echo ""
            echo -e "    ${RED}${CROSS} Project directory not found for: ${project}${NC}"
            echo ""
            echo -e "    ${DIM}Available compose directories:${NC}"
            # List all found compose directories
            local all_dirs=$(find_compose_projects)
            if [ -n "$all_dirs" ]; then
                echo "$all_dirs" | while read -r dir; do
                    echo -e "        ${DIM}- $dir${NC}"
                done
            fi
            press_enter
            return
        fi
    fi
    # Verify compose file exists
    local compose_file=""
    for file in "docker-compose.yml" "docker-compose.yaml" "compose.yml" "compose.yaml"; do
        if [ -f "$project_path/$file" ]; then
            compose_file="$file"
            break
        fi
    done
    if [ -z "$compose_file" ]; then
        echo -e "    ${RED}${CROSS} No compose file found in: ${project_path}${NC}"
        press_enter
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
        echo -e "    File:    ${DIM}${compose_file}${NC}"
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
        echo -e "        ${YELLOW}${BOLD}[1]${NC}  ${WHITE}View logs${NC}                           ${DIM}View project logs${NC}"
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
                    press_enter
                    refresh_cache
                fi
                ;;
            3)
                echo ""
                echo -e "    ${YELLOW}Starting project...${NC}"
                docker compose up -d
                echo ""
                echo -e "    ${GREEN}${BOLD}${CHECK}  Project started${NC}"
                press_enter
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
                    press_enter
                    refresh_cache
                fi
                ;;
            5)
                echo ""
                echo -e "    ${YELLOW}Restarting project...${NC}"
                docker compose restart
                echo ""
                echo -e "    ${GREEN}${BOLD}${CHECK}  Project restarted${NC}"
                press_enter
                refresh_cache
                ;;
            6)
                echo ""
                echo -e "    ${YELLOW}Pulling latest images...${NC}"
                docker compose pull
                echo ""
                echo -e "    ${GREEN}${BOLD}${CHECK}  Images pulled${NC}"
                echo -e "    ${DIM}Run 'docker compose up -d' to apply changes${NC}"
                press_enter
                ;;
            0)
                return
                ;;
            *)
                ;;
        esac
    done
}
# MODIFIED: View container logs with menu
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
        echo -e "${WHITE}${BOLD}    SELECT LOG VIEW:${NC}"
        echo ""
        echo -e "    ${YELLOW}[1]${NC} Last hour    ${YELLOW}[2]${NC} Last 100 lines    ${YELLOW}[3]${NC} Live logs    ${YELLOW}[0]${NC} Back"
        echo ""
        read -p "$(echo -e "    ${YELLOW}${BOLD}Select: ${NC}")" choice
        case $choice in
            1)
                clear
                echo ""
                echo -e "${BLUE}${BOLD}    Logs from last hour:${NC}"
                echo ""
                echo -e "${DIM}    ────────────────────────────────────────────────────────────────────${NC}"
                echo ""
                docker logs --since 1h "$container" 2>&1 | colorize_logs
                press_enter
                ;;
            2)
                clear
                echo ""
                echo -e "${BLUE}${BOLD}    Last 100 lines:${NC}"
                echo ""
                echo -e "${DIM}    ────────────────────────────────────────────────────────────────────${NC}"
                echo ""
                docker logs --tail 100 "$container" 2>&1 | colorize_logs
                press_enter
                ;;
            3)
                clear
                echo ""
                echo -e "${BLUE}${BOLD}    Following live logs (Ctrl+C to stop):${NC}"
                echo ""
                echo -e "${DIM}    ────────────────────────────────────────────────────────────────────${NC}"
                echo ""
                # FIXED: Proper live logs without buffering
                stdbuf -o0 -e0 docker logs -f --tail 50 "$container" 2>&1 | while IFS= read -r line; do
                    echo "$line" | colorize_logs
                done
                echo ""
                echo -e "    ${YELLOW}Log stream stopped${NC}"
                sleep 1
                ;;
            0|"")
                return
                ;;
            *)
                ;;
        esac
    done
}
# MODIFIED: View project logs with menu
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
        echo -e "${WHITE}${BOLD}    SELECT LOG VIEW:${NC}"
        echo ""
        echo -e "    ${YELLOW}[1]${NC} Last hour    ${YELLOW}[2]${NC} Last 100 lines    ${YELLOW}[3]${NC} Live logs    ${YELLOW}[0]${NC} Back"
        echo ""
        read -p "$(echo -e "    ${YELLOW}${BOLD}Select: ${NC}")" choice
        case $choice in
            1)
                clear
                echo ""
                echo -e "${BLUE}${BOLD}    Logs from last hour:${NC}"
                echo ""
                echo -e "${DIM}    ────────────────────────────────────────────────────────────────────${NC}"
                echo ""
                docker compose logs --since 1h 2>&1 | colorize_logs
                press_enter
                ;;
            2)
                clear
                echo ""
                echo -e "${BLUE}${BOLD}    Last 100 lines:${NC}"
                echo ""
                echo -e "${DIM}    ────────────────────────────────────────────────────────────────────${NC}"
                echo ""
                docker compose logs --tail 100 2>&1 | colorize_logs
                press_enter
                ;;
            3)
                clear
                echo ""
                echo -e "${BLUE}${BOLD}    Following live logs (Ctrl+C to stop):${NC}"
                echo ""
                echo -e "${DIM}    ────────────────────────────────────────────────────────────────────${NC}"
                echo ""
                # FIXED: Proper live logs without buffering
                stdbuf -o0 -e0 docker compose logs -f --tail 50 2>&1 | while IFS= read -r line; do
                    echo "$line" | colorize_logs
                done
                echo ""
                echo -e "    ${YELLOW}Log stream stopped${NC}"
                sleep 1
                ;;
            0|"")
                return
                ;;
            *)
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
# IMPROVED: Single deep cleanup with one confirmation
clean_docker() {
    clear
    echo ""
    echo ""
    echo -e "${CYAN}${BOLD}    ╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}    ║                                                                    ║${NC}"
    echo -e "${CYAN}${BOLD}    ║                    CLEAN DOCKER SYSTEM                            ║${NC}"
    echo -e "${CYAN}${BOLD}    ║                                                                    ║${NC}"
    echo -e "${CYAN}${BOLD}    ╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo ""
    echo -e "${WHITE}${BOLD}    CURRENT DISK USAGE${NC}"
    echo ""
    docker system df | sed 's/^/    /'
    echo ""
    echo ""
    echo -e "${DIM}    ────────────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo ""
    echo -e "${YELLOW}${BOLD}    This will remove:${NC}"
    echo ""
    echo -e "        ${DOT}  All stopped containers"
    echo -e "        ${DOT}  All unused networks"
    echo -e "        ${DOT}  ${ORANGE}${BOLD}ALL unused images${NC} ${DIM}(not used by any container)${NC}"
    echo -e "        ${DOT}  All build cache"
    echo -e "        ${DOT}  All unused volumes ${DIM}(if confirmed)${NC}"
    echo ""
    echo ""
    echo -e "    ${ORANGE}${WARNING}  This includes:${NC}"
    echo -e "        ${DIM}- Old image versions after updates${NC}"
    echo -e "        ${DIM}- Images from deleted projects${NC}"
    echo -e "        ${DIM}- Images pulled but never used${NC}"
    echo ""
    echo -e "    ${GREEN}${BOLD}✓  Safe: Running containers and their resources are protected${NC}"
    echo ""
    echo ""
    read -p "$(echo -e "    ${ORANGE}${BOLD}Proceed with cleanup? (y/N): ${NC}")" confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "    ${YELLOW}Step 1/3: Running system prune...${NC}"
        echo ""
        docker system prune -a -f 2>&1 | sed 's/^/    /'
        echo ""
        echo -e "    ${YELLOW}Step 2/3: Checking for unused volumes...${NC}"
        echo ""
        # Check and remove unused volumes without asking again
        local unused_volumes=$(docker volume ls -qf dangling=true 2>/dev/null | wc -l)
        if [ "$unused_volumes" -gt 0 ]; then
            echo -e "    ${YELLOW}Found ${unused_volumes} unused volumes. Removing...${NC}"
            docker volume prune -f 2>&1 | sed 's/^/    /'
        else
            echo -e "    ${GREEN}No unused volumes found${NC}"
        fi
        echo ""
        echo -e "    ${YELLOW}Step 3/3: Final cleanup...${NC}"
        echo ""
        # Clean up builder cache
        docker builder prune -af 2>/dev/null | sed 's/^/    /'
        echo ""
        echo -e "    ${GREEN}${BOLD}${CHECK}  Cleanup complete!${NC}"
        echo ""
        echo ""
        echo -e "${WHITE}${BOLD}    DISK USAGE AFTER CLEANUP${NC}"
        echo ""
        docker system df | sed 's/^/    /'
        press_enter
        refresh_cache
    fi
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
            c)
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
            *)
                ;;
        esac
    done
}
# Run main
main

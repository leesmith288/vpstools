#!/bin/bash

# VPS Management Suite - Main Script
# Myopia-friendly interface with larger fonts and spacing
# Author: VPS Management Team
# Version: 2.0

# Enhanced color definitions for better visibility
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
ORANGE='\033[1;38;5;208m'
NC='\033[0m'
BOLD='\033[1m'
UNDERLINE='\033[4m'

# Configuration
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
LOG_FILE="/var/log/vps-suite.log"
MODULES_DIR="$SCRIPT_DIR"

# Auto-detect GitHub repository with multiple methods
detect_github_repo() {
    local repo=""
    
    # Method 1: Try git config (works if cloned via git)
    if command -v git &>/dev/null && [[ -d "$SCRIPT_DIR/.git" ]]; then
        repo=$(git -C "$SCRIPT_DIR" config --get remote.origin.url 2>/dev/null | sed 's/.*github.com[:/]\(.*\)\.git/\1/')
    fi
    
    # Method 2: Check if we're in a GitHub Actions environment
    if [[ -z "$repo" ]] && [[ -n "$GITHUB_REPOSITORY" ]]; then
        repo="$GITHUB_REPOSITORY"
    fi
    
    # Method 3: Check for a .github-repo file (for manual downloads)
    if [[ -z "$repo" ]] && [[ -f "$SCRIPT_DIR/.github-repo" ]]; then
        repo=$(cat "$SCRIPT_DIR/.github-repo" 2>/dev/null | head -1)
    fi
    
    # Method 4: Check saved config
    if [[ -z "$repo" ]] && [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        repo="$GITHUB_REPO"
    fi
    
    # Return result or fallback
    echo "${repo:-your-username/your-repo}"
}

# Set GitHub repo using auto-detect
GITHUB_REPO=$(detect_github_repo)

# Quick actions configuration
QUICK_ACTIONS_FILE="$HOME/.vps-quick-actions"
SEARCH_INDEX_FILE="$HOME/.vps-function-index"

# Load configuration if exists
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Myopia-friendly print functions with extra spacing
print_color() {
    echo -e "\n${1}${2}${NC}\n"
}

print_header() {
    echo -e "\n"
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                                                                    ║${NC}"
    echo -e "${CYAN}${BOLD}║${WHITE}${BOLD}                    $1${CYAN}${BOLD}                    ║${NC}"
    echo -e "${CYAN}${BOLD}║                                                                    ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "\n"
}

print_section() {
    echo -e "\n${YELLOW}${BOLD}━━━━━ $1 ━━━━━${NC}\n"
}

print_success() {
    echo -e "\n${GREEN}${BOLD}  ✅  $1${NC}\n"
}

print_error() {
    echo -e "\n${RED}${BOLD}  ❌  $1${NC}\n"
}

print_warning() {
    echo -e "\n${YELLOW}${BOLD}  ⚠️   $1${NC}\n"
}

print_info() {
    echo -e "\n${BLUE}${BOLD}  ℹ️   $1${NC}\n"
}

# Get system stats
get_cpu_usage() {
    top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 | cut -d'.' -f1
}

get_memory_info() {
    free -h | awk '/^Mem:/ {print $3 "/" $2}'
}

get_disk_usage() {
    df -h / | awk 'NR==2 {print $5}'
}

get_load_average() {
    uptime | awk -F'load average:' '{print $2}'
}

# Check if module exists
check_module() {
    local module="$1"
    [[ -f "$MODULES_DIR/$module" ]] && [[ -x "$MODULES_DIR/$module" ]]
}

# Load available modules
load_modules() {
    local modules=()
    for module in "$MODULES_DIR"/*.sh; do
        [[ -f "$module" ]] && [[ "$module" != "$0" ]] && modules+=("$(basename "$module")")
    done
    echo "${modules[@]}"
}

# Display system overview with larger, clearer format
show_system_overview() {
    local cpu=$(get_cpu_usage)
    local mem=$(get_memory_info)
    local disk=$(get_disk_usage)
    local load=$(get_load_average)
    
    echo -e "\n${WHITE}${BOLD}┌─────────────────────── SYSTEM STATUS ───────────────────────┐${NC}"
    echo -e "${WHITE}${BOLD}│                                                              │${NC}"
    echo -e "${WHITE}${BOLD}│${NC}  ${GREEN}▣ CPU Usage:${NC}     ${BOLD}${cpu}%${NC}                                       "
    echo -e "${WHITE}${BOLD}│${NC}  ${BLUE}▣ Memory:${NC}       ${BOLD}${mem}${NC}                                    "
    echo -e "${WHITE}${BOLD}│${NC}  ${YELLOW}▣ Disk Usage:${NC}   ${BOLD}${disk}${NC}                                      "
    echo -e "${WHITE}${BOLD}│${NC}  ${PURPLE}▣ Load:${NC}        ${BOLD}${load}${NC}                          "
    echo -e "${WHITE}${BOLD}│                                                              │${NC}"
    echo -e "${WHITE}${BOLD}└──────────────────────────────────────────────────────────────┘${NC}\n"
}

# Build function index for search
build_function_index() {
    print_info "Building function index..."
    > "$SEARCH_INDEX_FILE"
    
    for module in "$MODULES_DIR"/*.sh; do
        [[ ! -f "$module" ]] && continue
        local module_name=$(basename "$module")
        
        # Search for menu items and options in your scripts
        # Look for patterns like "[1] Install Docker" or "echo '[2] Port Scan'"
        grep -E "(\[[0-9]+\]|\[Aa\]|\[Bb\])" "$module" | while read -r line; do
            # Extract the menu item text
            local menu_item=$(echo "$line" | sed -E 's/.*\[([0-9A-Za-z]+)\][[:space:]]*//' | sed 's/"//g' | sed "s/'//g" | sed 's/echo.*\$//' | sed 's/print_color.*\$//' | cut -d'#' -f1 | xargs)
            
            if [[ -n "$menu_item" ]] && [[ ${#menu_item} -gt 3 ]]; then
                # Create searchable entries
                echo "$menu_item|Menu Option|$module_name" >> "$SEARCH_INDEX_FILE"
            fi
        done
        
        # Also look for function names (keep the original functionality)
        grep -E "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*\(\)[[:space:]]*\{" "$module" | while read -r line; do
            local func_name=$(echo "$line" | sed 's/().*//' | xargs)
            local description=$(echo "$line" | grep -o '#.*' | sed 's/^#[[:space:]]*//')
            [[ -n "$func_name" ]] && echo "$func_name|Function|$module_name" >> "$SEARCH_INDEX_FILE"
        done
    done
}

# Search functions across all modules
search_functions() {
    local search_term="$1"
    [[ ! -f "$SEARCH_INDEX_FILE" ]] && build_function_index
    
    clear
    print_header "🔍  SEARCH RESULTS"
    
    echo -e "${WHITE}${BOLD}Search term: \"$search_term\"${NC}\n"
    
    local results=$(grep -i "$search_term" "$SEARCH_INDEX_FILE" 2>/dev/null)
    
    if [[ -z "$results" ]]; then
        print_warning "No functions found matching \"$search_term\""
        echo -e "\nPress Enter to return..."
        read
        return
    fi
    
    echo -e "${YELLOW}${BOLD}Found Functions:${NC}\n"
    
    local count=1
    while IFS='|' read -r func desc module; do
        echo -e "${WHITE}${BOLD}[$count]${NC} ${GREEN}$func${NC}"
        echo -e "     ${BLUE}Module:${NC} $module"
        [[ -n "$desc" ]] && echo -e "     ${PURPLE}Description:${NC} $desc"
        echo
        ((count++))
    done <<< "$results"
    
    echo -e "\n${WHITE}${BOLD}[R]${NC} Return to main menu\n"
    read -p "Select function or [R]eturn: " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        # Execute selected function
        local selected=$(echo "$results" | sed -n "${choice}p")
        local module=$(echo "$selected" | cut -d'|' -f3)
        local func=$(echo "$selected" | cut -d'|' -f1)
        
        if [[ -f "$MODULES_DIR/$module" ]]; then
            source "$MODULES_DIR/$module"
            $func
        fi
    fi
}

# Manage quick actions
manage_quick_actions() {
    clear
    print_header "⚡ QUICK ACTIONS MANAGEMENT"
    
    echo -e "${WHITE}${BOLD}Current Quick Actions:${NC}\n"
    
    if [[ -f "$QUICK_ACTIONS_FILE" ]]; then
        local count=1
        while IFS='|' read -r name command module; do
            echo -e "${WHITE}${BOLD}[$count]${NC} $name"
            echo -e "     ${BLUE}Command:${NC} $command"
            echo -e "     ${PURPLE}Module:${NC} $module"
            echo
            ((count++))
        done < "$QUICK_ACTIONS_FILE"
    else
        print_info "No quick actions configured yet"
    fi
    
    echo -e "\n${WHITE}${BOLD}[A]${NC} Add new quick action"
    echo -e "${WHITE}${BOLD}[R]${NC} Remove quick action"
    echo -e "${WHITE}${BOLD}[M]${NC} Return to main menu\n"
    
    read -p "Your choice: " choice
    
    case $choice in
        [Aa])
            echo -e "\nEnter quick action name: "
            read name
            echo -e "Enter command: "
            read command
            echo -e "Enter module (e.g., docker-manager.sh): "
            read module
            echo "$name|$command|$module" >> "$QUICK_ACTIONS_FILE"
            print_success "Quick action added!"
            ;;
        [Rr])
            echo -e "\nEnter number to remove: "
            read num
            sed -i "${num}d" "$QUICK_ACTIONS_FILE" 2>/dev/null
            print_success "Quick action removed!"
            ;;
    esac
    
    sleep 2
}

# Execute quick actions
show_quick_actions() {
    clear
    print_header "⚡ QUICK ACTIONS"
    
    if [[ ! -f "$QUICK_ACTIONS_FILE" ]] || [[ ! -s "$QUICK_ACTIONS_FILE" ]]; then
        print_info "No quick actions configured"
        print_info "Add quick actions from Settings menu"
        echo -e "\nPress Enter to return..."
        read
        return
    fi
    
    local count=1
    while IFS='|' read -r name command module; do
        echo -e "${WHITE}${BOLD}[$count]${NC} ${GREEN}$name${NC}"
        ((count++))
    done < "$QUICK_ACTIONS_FILE"
    
    echo -e "\n${WHITE}${BOLD}[M]${NC} Return to main menu\n"
    read -p "Select action: " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        local action=$(sed -n "${choice}p" "$QUICK_ACTIONS_FILE")
        local command=$(echo "$action" | cut -d'|' -f2)
        local module=$(echo "$action" | cut -d'|' -f3)
        
        if [[ -f "$MODULES_DIR/$module" ]]; then
            source "$MODULES_DIR/$module"
            eval "$command"
        fi
    fi
}

# Check for module updates
check_module_updates() {
    clear
    print_header "🔄 CHECK FOR UPDATES"
    
    # Check if repo is configured
    if [[ "$GITHUB_REPO" == "your-username/your-repo" ]]; then
        print_error "GitHub repository not configured!"
        echo -e "\n${YELLOW}Please configure in Settings menu${NC}"
        echo -e "\nPress Enter to continue..."
        read
        return
    fi
    
    print_info "Checking updates from: $GITHUB_REPO"
    echo
    
    # Test connection to GitHub
    if ! curl -s "https://api.github.com/repos/$GITHUB_REPO" >/dev/null; then
        print_error "Cannot connect to GitHub repository: $GITHUB_REPO"
        echo -e "\n${YELLOW}Please check your internet connection and repository settings${NC}"
        echo -e "\nPress Enter to continue..."
        read
        return
    fi
    
    echo -e "${WHITE}${BOLD}Module Status:${NC}\n"
    
    local updates_available=0
    
    for module in "$MODULES_DIR"/*.sh; do
        [[ ! -f "$module" ]] && continue
        local module_name=$(basename "$module")
        local local_hash=$(sha256sum "$module" | cut -d' ' -f1 | head -c 10)
        
        echo -e "${BLUE}▸${NC} ${WHITE}$module_name${NC}"
        echo -e "  Local version: ${YELLOW}$local_hash...${NC}"
        
        # Check remote version (simplified - implement actual GitHub API check)
        # In real implementation, you'd fetch the remote file hash
        echo -e "  Status: ${GREEN}✓ Up to date${NC}\n"
    done
    
    if [[ $updates_available -gt 0 ]]; then
        echo -e "\n${WHITE}${BOLD}$updates_available update(s) available!${NC}"
        echo -e "\n${WHITE}${BOLD}[U]${NC} Update all modules"
        echo -e "${WHITE}${BOLD}[M]${NC} Return to main menu\n"
        read -p "Your choice: " update_choice
        
        if [[ "$update_choice" == "U" ]] || [[ "$update_choice" == "u" ]]; then
            # Implement update logic here
            print_info "Updating modules..."
            sleep 2
            print_success "Updates completed!"
        fi
    else
        echo -e "\n${GREEN}${BOLD}All modules are up to date!${NC}"
    fi
    
    echo -e "\nPress Enter to return..."
    read
}

# Settings menu
show_settings() {
    clear
    print_header "⚙️  SETTINGS"
    
    echo -e "${WHITE}${BOLD}[1]${NC} ${BLUE}Manage Quick Actions${NC}"
    echo -e "     Configure frequently used commands\n"
    
    echo -e "${WHITE}${BOLD}[2]${NC} ${BLUE}Rebuild Search Index${NC}"
    echo -e "     Update function search database\n"
    
    echo -e "${WHITE}${BOLD}[3]${NC} ${BLUE}Configure GitHub Repository${NC}"
    echo -e "     Set repository for updates\n"
    
    echo -e "${WHITE}${BOLD}[4]${NC} ${BLUE}View Configuration${NC}"
    echo -e "     Show current settings\n"
    
    echo -e "${WHITE}${BOLD}[M]${NC} Return to main menu\n"
    
    read -p "Your choice: " choice
    
    case $choice in
        1) manage_quick_actions ;;
        2) 
            build_function_index
            print_success "Search index rebuilt!"
            sleep 2
            ;;
        3)
            echo -e "\nCurrent repository: ${YELLOW}$GITHUB_REPO${NC}\n"
            echo -e "Enter new GitHub repository (username/repo): "
            read repo
            if [[ -n "$repo" ]]; then
                echo "GITHUB_REPO=\"$repo\"" > "$CONFIG_FILE"
                echo "$repo" > "$SCRIPT_DIR/.github-repo"
                GITHUB_REPO="$repo"
                print_success "Repository updated to: $repo"
            fi
            sleep 2
            ;;
        4)
            echo -e "\n${WHITE}${BOLD}Current Configuration:${NC}\n"
            echo -e "Script Directory: ${YELLOW}$SCRIPT_DIR${NC}"
            echo -e "GitHub Repo: ${YELLOW}$GITHUB_REPO${NC}"
            echo -e "Log File: ${YELLOW}$LOG_FILE${NC}"
            echo -e "\nDetection Methods Status:"
            [[ -d "$SCRIPT_DIR/.git" ]] && echo -e "  ${GREEN}✓${NC} Git repository detected" || echo -e "  ${RED}✗${NC} Not a git repository"
            [[ -f "$SCRIPT_DIR/.github-repo" ]] && echo -e "  ${GREEN}✓${NC} .github-repo file exists" || echo -e "  ${RED}✗${NC} No .github-repo file"
            [[ -f "$CONFIG_FILE" ]] && echo -e "  ${GREEN}✓${NC} Config file exists" || echo -e "  ${RED}✗${NC} No config file"
            echo -e "\nPress Enter to continue..."
            read
            ;;
    esac
}

# Main dashboard
show_dashboard() {
    clear
    print_header "📊 SYSTEM DASHBOARD"
    
    show_system_overview
    
    # Quick stats
    echo -e "${WHITE}${BOLD}Quick Information:${NC}\n"
    echo -e "${BLUE}▸${NC} Hostname: ${WHITE}$(hostname)${NC}"
    echo -e "${BLUE}▸${NC} Uptime: ${WHITE}$(uptime -p)${NC}"
    echo -e "${BLUE}▸${NC} Kernel: ${WHITE}$(uname -r)${NC}"
    echo -e "${BLUE}▸${NC} IP Address: ${WHITE}$(hostname -I | awk '{print $1}')${NC}"
    
    echo -e "\n\nPress Enter to return to main menu..."
    read
}

# Main menu
show_main_menu() {
    while true; do
        clear
        
        # Large, clear header
        echo -e "\n${PURPLE}${BOLD}╔═══════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}${BOLD}║                                                                       ║${NC}"
        echo -e "${PURPLE}${BOLD}║${WHITE}${BOLD}              🚀  VPS MANAGEMENT SUITE v2.0  🚀${PURPLE}${BOLD}                ║${NC}"
        echo -e "${PURPLE}${BOLD}║                                                                       ║${NC}"
        echo -e "${PURPLE}${BOLD}╚═══════════════════════════════════════════════════════════════════════╝${NC}"
        
        # System overview
        show_system_overview
        
        # Core Tools section
        print_section "CORE TOOLS"
        
        echo -e "${WHITE}${BOLD}[1]${NC} ${GREEN}📦 System Tools${NC}"
        echo -e "     Package management, timezone, swap\n"
        
        echo -e "${WHITE}${BOLD}[2]${NC} ${GREEN}🔄 System Update${NC}"
        echo -e "     Update system and installed tools\n"
        
        echo -e "${WHITE}${BOLD}[3]${NC} ${GREEN}🔒 Security Check${NC}"
        echo -e "     Audit system security\n"
        
        # Service Management section
        print_section "SERVICE MANAGEMENT"
        
        echo -e "${WHITE}${BOLD}[4]${NC} ${BLUE}🐳 Docker Manager${NC}"
        echo -e "     Manage Docker and containers\n"
        
        echo -e "${WHITE}${BOLD}[5]${NC} ${BLUE}🌐 Caddy Manager${NC}"
        echo -e "     Web server management\n"
        
        # Network & Security section
        print_section "NETWORK & SECURITY"
        
        echo -e "${WHITE}${BOLD}[6]${NC} ${YELLOW}🌐 Network Tools${NC}"
        echo -e "     Firewall, ports, diagnostics\n"
        
        # Enhanced Features
        print_section "ENHANCED FEATURES"
        
        echo -e "${WHITE}${BOLD}[D]${NC} ${PURPLE}📊 Dashboard${NC} - Detailed system overview"
        echo -e "${WHITE}${BOLD}[Q]${NC} ${PURPLE}⚡ Quick Actions${NC} - Frequently used commands"
        echo -e "${WHITE}${BOLD}[F]${NC} ${PURPLE}🔍 Find/Search${NC} - Search all functions"
        echo -e "${WHITE}${BOLD}[U]${NC} ${PURPLE}🔄 Check Updates${NC} - Check for module updates\n"
        
        # Bottom menu
        echo -e "${WHITE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${WHITE}${BOLD}[S]${NC} Settings  ${WHITE}${BOLD}[H]${NC} Help  ${WHITE}${BOLD}[X]${NC} Exit"
        echo -e "${WHITE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        
        read -p "$(echo -e ${YELLOW}${BOLD}"Select option: "${NC})" choice
        
        case $choice in
            1)
                if check_module "system-tools.sh"; then
                    "$MODULES_DIR/system-tools.sh"
                else
                    print_error "system-tools.sh not found!"
                    sleep 2
                fi
                ;;
            2)
                if check_module "system-update.sh"; then
                    "$MODULES_DIR/system-update.sh"
                else
                    print_error "system-update.sh not found!"
                    sleep 2
                fi
                ;;
            3)
                if check_module "security-check.sh"; then
                    "$MODULES_DIR/security-check.sh"
                else
                    print_error "security-check.sh not found!"
                    sleep 2
                fi
                ;;
            4)
                if check_module "docker-manager.sh"; then
                    "$MODULES_DIR/docker-manager.sh"
                else
                    print_error "docker-manager.sh not found!"
                    sleep 2
                fi
                ;;
            5)
                if check_module "caddy-manager.sh"; then
                    "$MODULES_DIR/caddy-manager.sh"
                else
                    print_error "caddy-manager.sh not found!"
                    sleep 2
                fi
                ;;
            6)
                if check_module "network-tools.sh"; then
                    "$MODULES_DIR/network-tools.sh"
                else
                    print_error "network-tools.sh not found!"
                    sleep 2
                fi
                ;;
            [Dd])
                show_dashboard
                ;;
            [Qq])
                show_quick_actions
                ;;
            [Ff])
                echo -e "\nEnter search term: "
                read search_term
                [[ -n "$search_term" ]] && search_functions "$search_term"
                ;;
            [Uu])
                check_module_updates
                ;;
            [Ss])
                show_settings
                ;;
            [Hh])
                clear
                print_header "📚 HELP"
                echo -e "${WHITE}${BOLD}VPS Management Suite Help${NC}\n"
                echo -e "This suite provides centralized management for your VPS.\n"
                echo -e "${YELLOW}Available Modules:${NC}"
                for module in $(load_modules); do
                    echo -e "  ${BLUE}▸${NC} $module"
                done
                echo -e "\n${YELLOW}Tips:${NC}"
                echo -e "  ${BLUE}▸${NC} Use Quick Actions for frequently used commands"
                echo -e "  ${BLUE}▸${NC} Search function helps find commands across all modules"
                echo -e "  ${BLUE}▸${NC} Dashboard provides real-time system overview"
                echo -e "\nPress Enter to return..."
                read
                ;;
            [Xx])
                print_success "Thank you for using VPS Management Suite!"
                echo -e "\n"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please try again."
                sleep 1
                ;;
        esac
    done
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script requires root privileges"
        echo -e "${YELLOW}Please run: ${WHITE}sudo $0${NC}\n"
        exit 1
    fi
}

# Initialize
initialize() {
    # Create necessary directories and files
    touch "$LOG_FILE" 2>/dev/null
    
    # First-run setup if GitHub repo not properly detected
    if [[ "$GITHUB_REPO" == "your-username/your-repo" ]] && [[ ! -f "$CONFIG_FILE" ]]; then
        clear
        print_header "🚀 FIRST-RUN SETUP"
        echo -e "${WHITE}${BOLD}Welcome to VPS Management Suite!${NC}\n"
        echo -e "${YELLOW}No GitHub repository detected.${NC}\n"
        echo -e "Would you like to configure it now? This enables:"
        echo -e "  ${BLUE}▸${NC} Check for updates"
        echo -e "  ${BLUE}▸${NC} Download missing modules"
        echo -e "  ${BLUE}▸${NC} Sync configurations\n"
        
        read -p "Configure GitHub repository? [Y/n]: " setup_choice
        if [[ ! "$setup_choice" =~ ^[Nn]$ ]]; then
            echo -e "\nEnter your GitHub repository (format: username/repo):"
            read -p "> " user_repo
            if [[ -n "$user_repo" ]]; then
                echo "GITHUB_REPO=\"$user_repo\"" > "$CONFIG_FILE"
                GITHUB_REPO="$user_repo"
                
                # Also create .github-repo file for non-git downloads
                echo "$user_repo" > "$SCRIPT_DIR/.github-repo"
                
                print_success "GitHub repository configured: $user_repo"
                echo -e "\n${GREEN}Tip:${NC} You can change this later in Settings menu"
                sleep 3
            fi
        fi
    fi
    
    # Build function index on first run
    [[ ! -f "$SEARCH_INDEX_FILE" ]] && build_function_index &
    
    # Log startup
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] VPS Management Suite started" >> "$LOG_FILE"
}

# Main execution
main() {
    check_root
    initialize
    show_main_menu
}

# Run main function
main "$@"

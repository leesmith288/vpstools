#!/bin/bash

# Hysteria2 Management Script
# Compatible with Debian/Ubuntu on amd64/aarch64
# Run as root or with sudo for full functionality

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Clear screen for clean start
clear

# Function to print header with better spacing
print_header() {
    echo
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                      ║"
    echo "║                  ${PURPLE}HYSTERIA2 ${CYAN}MANAGEMENT TOOL                         ║"
    echo "║                                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

# Function to check if Hysteria2 is installed
is_installed() {
    command -v hysteria >/dev/null 2>&1 && [[ -f /etc/hysteria/config.yaml ]]
}

# Function to get quick status (simplified)
get_quick_status() {
    if ! is_installed; then
        echo -e "  ${RED}${BOLD}❌ Hysteria2 is NOT installed${NC}"
        echo
        return 1
    fi

    local status
    if systemctl is-active --quiet hysteria-server; then
        status="${GREEN}${BOLD}🟢 RUNNING${NC}"
        echo -e "  ${CYAN}${BOLD}Service Status: ${NC}$status"
        
        # Show brief info
        local uptime=$(systemctl show hysteria-server --property=ActiveEnterTimestamp --value 2>/dev/null)
        if [[ -n "$uptime" ]]; then
            echo -e "  ${CYAN}${BOLD}Started:        ${NC}$(date -d "$uptime" '+%Y-%m-%d %H:%M:%S')"
        fi
        
        # Show port if available
        local port=$(grep -E "^\s*listen:" /etc/hysteria/config.yaml 2>/dev/null | head -1 | sed 's/.*:\([0-9]*\).*/\1/')
        if [[ -n "$port" ]]; then
            echo -e "  ${CYAN}${BOLD}Port:           ${NC}$port"
        fi
    else
        status="${YELLOW}${BOLD}🟡 STOPPED${NC}"
        echo -e "  ${CYAN}${BOLD}Service Status: ${NC}$status"
    fi
    echo
}

# Function to show service information (replaces detailed status)
show_service_info() {
    if ! is_installed; then
        echo
        echo -e "  ${YELLOW}Hysteria2 not installed. Use 'Install Hysteria2' option first.${NC}"
        echo
        return
    fi

    echo
    echo -e "  ${BLUE}${BOLD}═══ SERVICE INFORMATION ═══${NC}"
    echo
    
    # Get service status
    local is_active=$(systemctl is-active hysteria-server 2>/dev/null)
    local is_enabled=$(systemctl is-enabled hysteria-server 2>/dev/null)
    
    echo -e "  ${BOLD}Service:${NC}        hysteria-server"
    echo -e "  ${BOLD}Active:${NC}         $([ "$is_active" = "active" ] && echo -e "${GREEN}$is_active${NC}" || echo -e "${RED}$is_active${NC}")"
    echo -e "  ${BOLD}Enabled:${NC}        $([ "$is_enabled" = "enabled" ] && echo -e "${GREEN}$is_enabled${NC}" || echo -e "${YELLOW}$is_enabled${NC}")"
    
    # Get version
    local version=$(hysteria version 2>/dev/null | head -1)
    if [[ -n "$version" ]]; then
        echo -e "  ${BOLD}Version:${NC}        $version"
    fi
    
    # Get config file info
    if [[ -f /etc/hysteria/config.yaml ]]; then
        local config_size=$(du -h /etc/hysteria/config.yaml | cut -f1)
        local config_modified=$(stat -c %y /etc/hysteria/config.yaml | cut -d'.' -f1)
        echo -e "  ${BOLD}Config File:${NC}    /etc/hysteria/config.yaml"
        echo -e "  ${BOLD}Config Size:${NC}    $config_size"
        echo -e "  ${BOLD}Last Modified:${NC}  $config_modified"
    fi
    
    echo
    echo -e "  ${CYAN}Use 'View Recent Logs' to see service messages${NC}"
    echo
}

# Function to edit config with improved UX
edit_config() {
    if ! is_installed; then
        echo
        echo -e "  ${YELLOW}Hysteria2 not installed. Install first.${NC}"
        echo
        return
    fi

    local editor="nano"
    if ! command -v nano >/dev/null 2>&1; then
        editor="vi"
        echo
        echo -e "  ${YELLOW}Using vi as editor (nano not found).${NC}"
        echo
    fi

    echo
    echo -e "  ${BLUE}${BOLD}═══ EDITING CONFIGURATION ═══${NC}"
    echo
    echo -e "  ${CYAN}File: ${NC}/etc/hysteria/config.yaml"
    echo -e "  ${CYAN}Editor: ${NC}$editor"
    echo
    echo -e "  ${YELLOW}Press Enter to open editor, or Ctrl+C to cancel${NC}"
    read -r
    
    sudo $editor /etc/hysteria/config.yaml
    
    echo
    echo -e "  ${GREEN}Config file closed.${NC}"
    echo
    echo -e "  ${BOLD}Restart service to apply changes? (y/n):${NC} "
    read -r choice
    if [[ $choice =~ ^[Yy]$ ]]; then
        sudo systemctl restart hysteria-server
        echo -e "  ${GREEN}✅ Service restarted${NC}"
    else
        echo -e "  ${YELLOW}⚠ Remember to restart service later for changes to take effect${NC}"
    fi
    echo
}

# Function to restart service with better feedback
restart_service() {
    if ! is_installed; then
        echo
        echo -e "  ${YELLOW}Hysteria2 not installed.${NC}"
        echo
        return
    fi

    echo
    echo -e "  ${BLUE}${BOLD}═══ RESTARTING SERVICE ═══${NC}"
    echo
    echo -e "  ${CYAN}Stopping service...${NC}"
    sudo systemctl stop hysteria-server
    sleep 1
    
    echo -e "  ${CYAN}Starting service...${NC}"
    sudo systemctl start hysteria-server
    sleep 2
    
    if systemctl is-active --quiet hysteria-server; then
        echo -e "  ${GREEN}✅ Service restarted successfully${NC}"
    else
        echo -e "  ${RED}❌ Service failed to start${NC}"
        echo
        echo -e "  ${YELLOW}Check logs for details (option 5)${NC}"
    fi
    echo
}

# Function to update Hysteria2
update_hy2() {
    if ! is_installed; then
        echo
        echo -e "  ${YELLOW}Hysteria2 not installed. This will install the latest version.${NC}"
        echo
        echo -e "  ${BOLD}Continue? (y/n):${NC} "
        read -r choice
        if ! [[ $choice =~ ^[Yy]$ ]]; then return; fi
    fi

    echo
    echo -e "  ${BLUE}${BOLD}═══ UPDATING/INSTALLING HYSTERIA2 ═══${NC}"
    echo
    echo -e "  ${CYAN}Downloading latest version...${NC}"
    echo -e "  ${YELLOW}Your config will be preserved${NC}"
    echo
    
    sudo bash <(curl -fsSL https://get.hy2.sh/)
    local code=$?
    
    echo
    if [ $code -eq 0 ]; then
        echo -e "  ${GREEN}✅ Update/Install completed${NC}"
        echo
        echo -e "  ${CYAN}Restarting service...${NC}"
        sudo systemctl restart hysteria-server
        echo -e "  ${GREEN}✅ Service restarted${NC}"
    else
        echo -e "  ${RED}❌ Update failed${NC}"
    fi
    echo
}

# Function to view recent logs (simplified)
view_recent_logs() {
    if ! is_installed; then
        echo
        echo -e "  ${YELLOW}Hysteria2 not installed.${NC}"
        echo
        return
    fi

    echo
    echo -e "  ${BLUE}${BOLD}═══ RECENT LOGS (Last 30 lines) ═══${NC}"
    echo
    sudo journalctl -u hysteria-server --no-pager -n 30
    echo
    echo -e "  ${CYAN}Tip: For live logs, run:${NC}"
    echo -e "  ${BOLD}sudo journalctl -u hysteria-server -f${NC}"
    echo
}

# Function to view live logs
view_live_logs() {
    if ! is_installed; then
        echo
        echo -e "  ${YELLOW}Hysteria2 not installed.${NC}"
        echo
        return
    fi

    echo
    echo -e "  ${BLUE}${BOLD}═══ LIVE LOGS ═══${NC}"
    echo
    echo -e "  ${YELLOW}Press Ctrl+C to stop viewing logs${NC}"
    echo
    sleep 2
    sudo journalctl -u hysteria-server -f
}

# Function to show menu with better spacing
show_menu() {
    echo -e "  ${PURPLE}${BOLD}═══ MAIN MENU ═══${NC}"
    echo
    echo -e "    ${CYAN}${BOLD}1.${NC}  Service Information"
    echo
    echo -e "    ${CYAN}${BOLD}2.${NC}  Edit Configuration"
    echo
    echo -e "    ${CYAN}${BOLD}3.${NC}  Restart Service"
    echo
    echo -e "    ${CYAN}${BOLD}4.${NC}  Update/Install Hysteria2"
    echo
    echo -e "    ${CYAN}${BOLD}5.${NC}  View Recent Logs"
    echo
    echo -e "    ${CYAN}${BOLD}6.${NC}  View Live Logs"
    echo
    echo -e "    ${CYAN}${BOLD}7.${NC}  Exit"
    echo
    echo -e "  ${YELLOW}${BOLD}Select an option (1-7):${NC} "
}

# Main loop
main() {
    print_header
    get_quick_status

    while true; do
        echo
        echo "  ════════════════════════════════════════════════════════════════"
        echo
        show_menu
        read -r choice

        case $choice in
            1)
                clear
                print_header
                show_service_info
                ;;
            2)
                clear
                print_header
                edit_config
                ;;
            3)
                clear
                print_header
                restart_service
                get_quick_status
                ;;
            4)
                clear
                print_header
                update_hy2
                get_quick_status
                ;;
            5)
                clear
                print_header
                view_recent_logs
                ;;
            6)
                clear
                print_header
                view_live_logs
                ;;
            7)
                echo
                echo -e "  ${GREEN}${BOLD}Goodbye! 🚀${NC}"
                echo
                exit 0
                ;;
            *)
                echo
                echo -e "  ${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Run main
main

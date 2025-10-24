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

# Function to print header
print_header() {
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                  ${PURPLE}HYSTERIA2 ${CYAN}MANAGEMENT TOOL${NC}${CYAN}${BOLD}                  ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

# Function to check if Hysteria2 is installed
is_installed() {
    command -v hysteria >/dev/null 2>&1 && [[ -f /etc/hysteria/config.yaml ]]
}

# Function to get status summary
get_status() {
    if ! is_installed; then
        echo -e "${RED}${BOLD}❌ Hysteria2 is NOT installed.${NC}"
        return 1
    fi

    local status
    if systemctl is-active --quiet hysteria-server; then
        status="${GREEN}${BOLD}🟢 ACTIVE (running)${NC}"
    else
        status="${YELLOW}${BOLD}🟡 INACTIVE (stopped/failed)${NC}"
    fi

    echo -e "${CYAN}${BOLD}Status:${NC} $status"
    echo
}

# Function to show detailed status
show_detailed_status() {
    if ! is_installed; then
        echo -e "${YELLOW}Hysteria2 not installed. Use 'Install Hysteria2' option first.${NC}"
        return
    fi

    echo -e "${BLUE}${BOLD}=== DETAILED HYSTERIA2 STATUS ===${NC}"
    echo
    systemctl status hysteria-server --no-pager -l
    echo
}

# Function to edit config
edit_config() {
    if ! is_installed; then
        echo -e "${YELLOW}Hysteria2 not installed. Install first.${NC}"
        return
    fi

    local editor="nano"
    if ! command -v nano >/dev/null 2>&1; then
        editor="vi"
        echo -e "${YELLOW}Using vi as editor (nano not found).${NC}"
    fi

    echo -e "${BLUE}${BOLD}=== EDITING CONFIG (/etc/hysteria/config.yaml) ===${NC}"
    echo "After editing, save and exit. The service will NOT auto-restart."
    echo
    sudo $editor /etc/hysteria/config.yaml
    echo
    echo -e "${GREEN}Config saved. Restart service to apply changes? (y/n)${NC}"
    read -r choice
    if [[ $choice =~ ^[Yy]$ ]]; then
        sudo systemctl restart hysteria-server
        echo -e "${GREEN}Service restarted.${NC}"
    fi
}

# Function to restart service
restart_service() {
    if ! is_installed; then
        echo -e "${YELLOW}Hysteria2 not installed.${NC}"
        return
    fi

    echo -e "${BLUE}${BOLD}=== RESTARTING HYSTERIA2 ===${NC}"
    sudo systemctl restart hysteria-server
    local code=$?
    if [ $code -eq 0 ]; then
        echo -e "${GREEN}✅ Service restarted successfully.${NC}"
    else
        echo -e "${RED}❌ Restart failed. Check status.${NC}"
    fi
    echo
}

# Function to update Hysteria2
update_hy2() {
    if ! is_installed; then
        echo -e "${YELLOW}Hysteria2 not installed. This will install the latest version.${NC}"
        echo "Continue? (y/n)"
        read -r choice
        if ! [[ $choice =~ ^[Yy]$ ]]; then return; fi
    fi

    echo -e "${BLUE}${BOLD}=== UPDATING/INSTALLING HYSTERIA2 ===${NC}"
    echo "This will download and install/upgrade to the latest version."
    echo "Your config will be preserved."
    echo
    sudo bash <(curl -fsSL https://get.hy2.sh/)
    local code=$?
    if [ $code -eq 0 ]; then
        echo -e "${GREEN}✅ Update/Install completed.${NC}"
        echo -e "${YELLOW}Restarting service...${NC}"
        sudo systemctl restart hysteria-server
    else
        echo -e "${RED}❌ Update failed.${NC}"
    fi
    echo
}

# Function to view logs
view_logs() {
    if ! is_installed; then
        echo -e "${YELLOW}Hysteria2 not installed.${NC}"
        return
    fi

    echo -e "${BLUE}${BOLD}=== HYSTERIA2 LOGS (Last 50 lines) ===${NC}"
    echo "Press Ctrl+C to exit logs."
    echo
    sudo journalctl -u hysteria-server --no-pager -n 50
    echo
    echo -e "${YELLOW}For live logs: journalctl -u hysteria-server -f${NC}"
}

# Function to show menu
show_menu() {
    echo -e "${PURPLE}${BOLD}=== MAIN MENU ===${NC}"
    echo
    echo -e "  ${CYAN}1.${NC} ${BOLD}Status Summary${NC}"
    echo -e "  ${CYAN}2.${NC} ${BOLD}Detailed Status${NC}"
    echo -e "  ${CYAN}3.${NC} ${BOLD}Edit Config${NC}"
    echo -e "  ${CYAN}4.${NC} ${BOLD}Restart Service${NC}"
    echo -e "  ${CYAN}5.${NC} ${BOLD}Update/Install Hysteria2${NC}"
    echo -e "  ${CYAN}6.${NC} ${BOLD}View Logs${NC}"
    echo -e "  ${CYAN}7.${NC} ${BOLD}Exit${NC}"
    echo
    echo -e "${YELLOW}Select an option (1-7): ${NC}"
}

# Main loop
main() {
    print_header
    get_status

    while true; do
        echo
        echo "────────────────────────────────────────────────────────"
        show_menu
        read -r choice

        case $choice in
            1)
                clear
                print_header
                get_status
                ;;
            2)
                clear
                print_header
                show_detailed_status
                ;;
            3)
                clear
                print_header
                edit_config
                ;;
            4)
                clear
                print_header
                restart_service
                get_status
                ;;
            5)
                clear
                print_header
                update_hy2
                get_status
                ;;
            6)
                clear
                print_header
                view_logs
                ;;
            7)
                echo -e "${GREEN}${BOLD}Goodbye! 🚀${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Run main
main
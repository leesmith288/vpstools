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
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                                                                      ║${NC}"
    echo -e "${CYAN}${BOLD}║                  ${PURPLE}HYSTERIA2${NC} ${CYAN}${BOLD}MANAGEMENT TOOL                         ║${NC}"
    echo -e "${CYAN}${BOLD}║                                                                      ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
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
    else
        status="${YELLOW}${BOLD}🟡 STOPPED${NC}"
    fi
    echo -e "  ${CYAN}${BOLD}Current Status: ${NC}$status"
    echo
}

# Function to show systemctl status (original command output)
show_service_status() {
    if ! is_installed; then
        echo
        echo -e "  ${YELLOW}${BOLD}Hysteria2 not installed. Use 'Install Hysteria2' option first.${NC}"
        echo
        return
    fi

    echo
    echo -e "  ${BLUE}${BOLD}═══ SERVICE STATUS ═══${NC}"
    echo
    systemctl status hysteria-server --no-pager
    echo
}

# Function to edit config with improved UX
edit_config() {
    if ! is_installed; then
        echo
        echo -e "  ${YELLOW}${BOLD}Hysteria2 not installed. Install first.${NC}"
        echo
        return
    fi

    # Check for available editors
    local editor=""
    if command -v nano >/dev/null 2>&1; then
        editor="nano"
    elif command -v vim >/dev/null 2>&1; then
        editor="vim"
    elif command -v vi >/dev/null 2>&1; then
        editor="vi"
    else
        echo
        echo -e "  ${RED}${BOLD}No text editor found (nano, vim, or vi).${NC}"
        echo
        return
    fi

    echo
    echo -e "  ${BLUE}${BOLD}═══ EDITING CONFIGURATION ═══${NC}"
    echo
    echo -e "  ${CYAN}${BOLD}File: ${NC}/etc/hysteria/config.yaml"
    echo -e "  ${CYAN}${BOLD}Editor: ${NC}$editor"
    echo
    echo -e "  ${YELLOW}${BOLD}Press Enter to open editor, or Ctrl+C to cancel${NC}"
    read -r
    
    if [[ -f /etc/hysteria/config.yaml ]]; then
        sudo $editor /etc/hysteria/config.yaml
        echo
        echo -e "  ${GREEN}${BOLD}Config file closed.${NC}"
        echo
        echo -n -e "  ${BOLD}Restart service to apply changes? (y/n): ${NC}"
        read -r choice
        if [[ $choice =~ ^[Yy]$ ]]; then
            sudo systemctl restart hysteria-server
            if systemctl is-active --quiet hysteria-server; then
                echo -e "  ${GREEN}${BOLD}✅ Service restarted successfully${NC}"
            else
                echo -e "  ${RED}${BOLD}❌ Service restart failed${NC}"
            fi
        else
            echo -e "  ${YELLOW}${BOLD}⚠ Remember to restart service later for changes to take effect${NC}"
        fi
    else
        echo -e "  ${RED}${BOLD}Config file not found at /etc/hysteria/config.yaml${NC}"
    fi
    echo
}

# Function to restart service with better feedback
restart_service() {
    if ! is_installed; then
        echo
        echo -e "  ${YELLOW}${BOLD}Hysteria2 not installed.${NC}"
        echo
        return
    fi

    echo
    echo -e "  ${BLUE}${BOLD}═══ RESTARTING SERVICE ═══${NC}"
    echo
    echo -e "  ${CYAN}${BOLD}Stopping service...${NC}"
    sudo systemctl stop hysteria-server
    sleep 1
    
    echo -e "  ${CYAN}${BOLD}Starting service...${NC}"
    sudo systemctl start hysteria-server
    sleep 2
    
    if systemctl is-active --quiet hysteria-server; then
        echo -e "  ${GREEN}${BOLD}✅ Service restarted successfully${NC}"
    else
        echo -e "  ${RED}${BOLD}❌ Service failed to start${NC}"
        echo
        echo -e "  ${YELLOW}${BOLD}Check logs for details (option 5)${NC}"
    fi
    echo
}

# Function to update Hysteria2 - FIXED
update_hy2() {
    if ! is_installed; then
        echo
        echo -e "  ${YELLOW}${BOLD}Hysteria2 not installed. This will install the latest version.${NC}"
        echo
        echo -n -e "  ${BOLD}Continue? (y/n): ${NC}"
        read -r choice
        if ! [[ $choice =~ ^[Yy]$ ]]; then return; fi
    fi

    echo
    echo -e "  ${BLUE}${BOLD}═══ UPDATING/INSTALLING HYSTERIA2 ═══${NC}"
    echo
    echo -e "  ${CYAN}${BOLD}Downloading latest version...${NC}"
    echo -e "  ${YELLOW}${BOLD}Your config will be preserved${NC}"
    echo
    
    # Download the install script to a temporary file first
    local temp_script="/tmp/hysteria_install_$$.sh"
    
    if curl -fsSL https://get.hy2.sh/ -o "$temp_script"; then
        chmod +x "$temp_script"
        sudo bash "$temp_script"
        local code=$?
        rm -f "$temp_script"
        
        echo
        if [ $code -eq 0 ]; then
            echo -e "  ${GREEN}${BOLD}✅ Update/Install completed${NC}"
            echo
            echo -e "  ${CYAN}${BOLD}Restarting service...${NC}"
            sudo systemctl daemon-reload
            sudo systemctl restart hysteria-server
            if systemctl is-active --quiet hysteria-server; then
                echo -e "  ${GREEN}${BOLD}✅ Service restarted${NC}"
            else
                echo -e "  ${YELLOW}${BOLD}⚠ Service not running. Check configuration.${NC}"
            fi
        else
            echo -e "  ${RED}${BOLD}❌ Installation script failed${NC}"
        fi
    else
        echo -e "  ${RED}${BOLD}❌ Failed to download installation script${NC}"
        echo -e "  ${YELLOW}${BOLD}Check your internet connection${NC}"
    fi
    echo
}

# Function to view recent logs (simplified)
view_recent_logs() {
    if ! is_installed; then
        echo
        echo -e "  ${YELLOW}${BOLD}Hysteria2 not installed.${NC}"
        echo
        return
    fi

    echo
    echo -e "  ${BLUE}${BOLD}═══ RECENT LOGS (Last 30 lines) ═══${NC}"
    echo
    
    if systemctl is-enabled hysteria-server >/dev/null 2>&1; then
        sudo journalctl -u hysteria-server --no-pager -n 30
    else
        echo -e "  ${YELLOW}${BOLD}Service is not enabled or logs are not available${NC}"
    fi
    
    echo
    echo -e "  ${CYAN}${BOLD}Tip: For live logs, use option 6${NC}"
    echo
}

# Function to view live logs
view_live_logs() {
    if ! is_installed; then
        echo
        echo -e "  ${YELLOW}${BOLD}Hysteria2 not installed.${NC}"
        echo
        return
    fi

    echo
    echo -e "  ${BLUE}${BOLD}═══ LIVE LOGS ═══${NC}"
    echo
    echo -e "  ${YELLOW}${BOLD}Press Ctrl+C to stop viewing logs${NC}"
    echo
    sleep 2
    
    if systemctl is-enabled hysteria-server >/dev/null 2>&1; then
        sudo journalctl -u hysteria-server -f
    else
        echo -e "  ${RED}${BOLD}Service is not enabled or logs are not available${NC}"
    fi
    echo
}

# Function to show menu with better spacing
show_menu() {
    echo -e "  ${PURPLE}${BOLD}╔════════════════════════════════════╗${NC}"
    echo -e "  ${PURPLE}${BOLD}║           MAIN MENU                ║${NC}"
    echo -e "  ${PURPLE}${BOLD}╚════════════════════════════════════╝${NC}"
    echo
    echo -e "    ${CYAN}${BOLD}【1】${NC} ${BOLD} Show Service Status${NC}"
    echo
    echo -e "    ${CYAN}${BOLD}【2】${NC} ${BOLD} Edit Configuration${NC}"
    echo
    echo -e "    ${CYAN}${BOLD}【3】${NC} ${BOLD} Restart Service${NC}"
    echo
    echo -e "    ${CYAN}${BOLD}【4】${NC} ${BOLD} Update/Install Hysteria2${NC}"
    echo
    echo -e "    ${CYAN}${BOLD}【5】${NC} ${BOLD} View Recent Logs${NC}"
    echo
    echo -e "    ${CYAN}${BOLD}【6】${NC} ${BOLD} View Live Logs${NC}"
    echo
    echo -e "    ${CYAN}${BOLD}【7】${NC} ${BOLD} Exit${NC}"
    echo
    echo -n -e "  ${YELLOW}${BOLD}Select an option (1-7): ${NC}"
}

# Main loop
main() {
    print_header
    get_quick_status

    while true; do
        echo
        echo -e "  ${BOLD}════════════════════════════════════════════════════════════════${NC}"
        echo
        show_menu
        read -r choice

        case $choice in
            1)
                clear
                print_header
                show_service_status
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
                echo -e "  ${RED}${BOLD}Invalid option. Please try again.${NC}"
                sleep 1
                ;;
        esac
    done
}

# Run main
main

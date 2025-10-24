
#!/bin/bash

# Singbox Management Script
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
    echo -e "${CYAN}${BOLD}║                    ${PURPLE}SINGBOX${NC} ${CYAN}${BOLD}MANAGEMENT TOOL                         ║${NC}"
    echo -e "${CYAN}${BOLD}║                                                                      ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

# Function to check if Singbox is installed
is_installed() {
    command -v sing-box >/dev/null 2>&1 && [[ -f /etc/sing-box/config.json ]]
}

# Function to get quick status
get_quick_status() {
    if ! is_installed; then
        echo -e "  ${RED}${BOLD}❌ Singbox is NOT installed${NC}"
        echo
        return 1
    fi

    local status
    if systemctl is-active --quiet sing-box; then
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
        echo -e "  ${YELLOW}${BOLD}Singbox not installed. Use 'Install Singbox' option first.${NC}"
        echo
        return
    fi

    echo
    echo -e "  ${BLUE}${BOLD}═══ SERVICE STATUS ═══${NC}"
    echo
    systemctl status sing-box --no-pager
    echo
}

# Function to edit config
edit_config() {
    if ! is_installed; then
        echo
        echo -e "  ${YELLOW}${BOLD}Singbox not installed. Install first.${NC}"
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
    echo -e "  ${CYAN}${BOLD}File: ${NC}/etc/sing-box/config.json"
    echo -e "  ${CYAN}${BOLD}Editor: ${NC}$editor"
    echo
    echo -e "  ${YELLOW}${BOLD}Press Enter to open editor, or Ctrl+C to cancel${NC}"
    read -r
    
    if [[ -f /etc/sing-box/config.json ]]; then
        # Backup config before editing
        sudo cp /etc/sing-box/config.json /etc/sing-box/config.json.backup
        echo -e "  ${GREEN}${BOLD}Config backed up to config.json.backup${NC}"
        echo
        
        sudo $editor /etc/sing-box/config.json
        echo
        echo -e "  ${GREEN}${BOLD}Config file closed.${NC}"
        echo
        
        # Check config validity
        echo -e "  ${CYAN}${BOLD}Checking configuration...${NC}"
        if sudo sing-box check -c /etc/sing-box/config.json >/dev/null 2>&1; then
            echo -e "  ${GREEN}${BOLD}✅ Configuration is valid${NC}"
            echo
            echo -n -e "  ${BOLD}Restart service to apply changes? (y/n): ${NC}"
            read -r choice
            if [[ $choice =~ ^[Yy]$ ]]; then
                sudo systemctl restart sing-box
                if systemctl is-active --quiet sing-box; then
                    echo -e "  ${GREEN}${BOLD}✅ Service restarted successfully${NC}"
                else
                    echo -e "  ${RED}${BOLD}❌ Service restart failed${NC}"
                    echo -e "  ${YELLOW}${BOLD}Restoring backup...${NC}"
                    sudo cp /etc/sing-box/config.json.backup /etc/sing-box/config.json
                    sudo systemctl restart sing-box
                fi
            else
                echo -e "  ${YELLOW}${BOLD}⚠ Remember to restart service later for changes to take effect${NC}"
            fi
        else
            echo -e "  ${RED}${BOLD}❌ Configuration is invalid!${NC}"
            echo -n -e "  ${BOLD}Restore backup? (y/n): ${NC}"
            read -r restore
            if [[ $restore =~ ^[Yy]$ ]]; then
                sudo cp /etc/sing-box/config.json.backup /etc/sing-box/config.json
                echo -e "  ${GREEN}${BOLD}Backup restored${NC}"
            fi
        fi
    else
        echo -e "  ${RED}${BOLD}Config file not found at /etc/sing-box/config.json${NC}"
    fi
    echo
}

# Function to restart service
restart_service() {
    if ! is_installed; then
        echo
        echo -e "  ${YELLOW}${BOLD}Singbox not installed.${NC}"
        echo
        return
    fi

    echo
    echo -e "  ${BLUE}${BOLD}═══ RESTARTING SERVICE ═══${NC}"
    echo
    echo -e "  ${CYAN}${BOLD}Stopping service...${NC}"
    sudo systemctl stop sing-box
    sleep 1
    
    echo -e "  ${CYAN}${BOLD}Starting service...${NC}"
    sudo systemctl start sing-box
    sleep 2
    
    if systemctl is-active --quiet sing-box; then
        echo -e "  ${GREEN}${BOLD}✅ Service restarted successfully${NC}"
    else
        echo -e "  ${RED}${BOLD}❌ Service failed to start${NC}"
        echo
        echo -e "  ${YELLOW}${BOLD}Check logs for details (option 5)${NC}"
    fi
    echo
}

# Function to update/install Singbox
update_singbox() {
    echo
    echo -e "  ${BLUE}${BOLD}═══ UPDATING/INSTALLING SINGBOX ═══${NC}"
    echo
    
    # Detect architecture
    local ARCH=$(uname -m)
    local SING_ARCH=""
    
    case $ARCH in
        x86_64|amd64)
            SING_ARCH="amd64"
            ;;
        aarch64|arm64)
            SING_ARCH="arm64"
            ;;
        *)
            echo -e "  ${RED}${BOLD}Unsupported architecture: $ARCH${NC}"
            return 1
            ;;
    esac
    
    echo -e "  ${CYAN}${BOLD}Detected architecture: ${NC}$SING_ARCH"
    echo
    
    # Backup existing config if it exists
    if [[ -f /etc/sing-box/config.json ]]; then
        echo -e "  ${CYAN}${BOLD}Backing up existing configuration...${NC}"
        sudo cp /etc/sing-box/config.json /tmp/sing-box-config.backup.json
    fi
    
    # Get latest version from GitHub
    echo -e "  ${CYAN}${BOLD}Checking latest version...${NC}"
    local LATEST_VERSION=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    
    if [[ -z "$LATEST_VERSION" ]]; then
        echo -e "  ${RED}${BOLD}Failed to get latest version${NC}"
        return 1
    fi
    
    echo -e "  ${CYAN}${BOLD}Latest version: ${NC}v$LATEST_VERSION"
    echo
    
    # Download and install
    echo -e "  ${CYAN}${BOLD}Downloading Singbox...${NC}"
    local DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v${LATEST_VERSION}/sing-box-${LATEST_VERSION}-linux-${SING_ARCH}.tar.gz"
    local TEMP_DIR="/tmp/sing-box-install-$$"
    
    mkdir -p "$TEMP_DIR"
    
    if wget -q --show-progress "$DOWNLOAD_URL" -O "$TEMP_DIR/sing-box.tar.gz"; then
        echo -e "  ${GREEN}${BOLD}✅ Download completed${NC}"
        echo
        
        # Extract and install
        echo -e "  ${CYAN}${BOLD}Installing...${NC}"
        cd "$TEMP_DIR"
        tar -xzf sing-box.tar.gz
        
        # Stop service if running
        if systemctl is-active --quiet sing-box; then
            sudo systemctl stop sing-box
        fi
        
        # Install binary
        sudo cp "sing-box-${LATEST_VERSION}-linux-${SING_ARCH}/sing-box" /usr/local/bin/
        sudo chmod +x /usr/local/bin/sing-box
        
        # Create directories if they don't exist
        sudo mkdir -p /etc/sing-box
        sudo mkdir -p /var/lib/sing-box
        
        # Create systemd service if it doesn't exist
        if [[ ! -f /etc/systemd/system/sing-box.service ]]; then
            echo -e "  ${CYAN}${BOLD}Creating systemd service...${NC}"
            sudo tee /etc/systemd/system/sing-box.service > /dev/null <<EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
        fi
        
        # Restore config if it was backed up
        if [[ -f /tmp/sing-box-config.backup.json ]]; then
            echo -e "  ${CYAN}${BOLD}Restoring configuration...${NC}"
            sudo cp /tmp/sing-box-config.backup.json /etc/sing-box/config.json
        elif [[ ! -f /etc/sing-box/config.json ]]; then
            echo -e "  ${YELLOW}${BOLD}No configuration found. Creating basic config...${NC}"
            sudo tee /etc/sing-box/config.json > /dev/null <<EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [],
  "outbounds": []
}
EOF
        fi
        
        # Reload systemd and enable service
        sudo systemctl daemon-reload
        sudo systemctl enable sing-box
        
        # Clean up
        cd /
        rm -rf "$TEMP_DIR"
        
        echo -e "  ${GREEN}${BOLD}✅ Singbox installed/updated successfully${NC}"
        echo
        echo -n -e "  ${BOLD}Start service now? (y/n): ${NC}"
        read -r choice
        if [[ $choice =~ ^[Yy]$ ]]; then
            sudo systemctl start sing-box
            if systemctl is-active --quiet sing-box; then
                echo -e "  ${GREEN}${BOLD}✅ Service started${NC}"
            else
                echo -e "  ${RED}${BOLD}❌ Service failed to start. Check your configuration.${NC}"
            fi
        fi
    else
        echo -e "  ${RED}${BOLD}❌ Download failed${NC}"
        rm -rf "$TEMP_DIR"
        return 1
    fi
    echo
}

# Function to view recent logs
view_recent_logs() {
    if ! is_installed; then
        echo
        echo -e "  ${YELLOW}${BOLD}Singbox not installed.${NC}"
        echo
        return
    fi

    echo
    echo -e "  ${BLUE}${BOLD}═══ RECENT LOGS (Last 30 lines) ═══${NC}"
    echo
    
    if systemctl is-enabled sing-box >/dev/null 2>&1; then
        sudo journalctl -u sing-box --no-pager -n 30
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
        echo -e "  ${YELLOW}${BOLD}Singbox not installed.${NC}"
        echo
        return
    fi

    echo
    echo -e "  ${BLUE}${BOLD}═══ LIVE LOGS ═══${NC}"
    echo
    echo -e "  ${YELLOW}${BOLD}Press Ctrl+C to stop viewing logs${NC}"
    echo
    sleep 2
    
    if systemctl is-enabled sing-box >/dev/null 2>&1; then
        sudo journalctl -u sing-box -f
    else
        echo -e "  ${RED}${BOLD}Service is not enabled or logs are not available${NC}"
    fi
    echo
}

# Function to check configuration
check_config() {
    if ! is_installed; then
        echo
        echo -e "  ${YELLOW}${BOLD}Singbox not installed.${NC}"
        echo
        return
    fi

    echo
    echo -e "  ${BLUE}${BOLD}═══ CHECKING CONFIGURATION ═══${NC}"
    echo
    echo -e "  ${CYAN}${BOLD}Config file: ${NC}/etc/sing-box/config.json"
    echo
    
    if sudo sing-box check -c /etc/sing-box/config.json; then
        echo
        echo -e "  ${GREEN}${BOLD}✅ Configuration is valid${NC}"
    else
        echo
        echo -e "  ${RED}${BOLD}❌ Configuration has errors${NC}"
    fi
    echo
}

# Function to show menu
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
    echo -e "    ${CYAN}${BOLD}【4】${NC} ${BOLD} Update/Install Singbox${NC}"
    echo
    echo -e "    ${CYAN}${BOLD}【5】${NC} ${BOLD} View Recent Logs${NC}"
    echo
    echo -e "    ${CYAN}${BOLD}【6】${NC} ${BOLD} View Live Logs${NC}"
    echo
    echo -e "    ${CYAN}${BOLD}【7】${NC} ${BOLD} Check Configuration${NC}"
    echo
    echo -e "    ${CYAN}${BOLD}【8】${NC} ${BOLD} Exit${NC}"
    echo
    echo -n -e "  ${YELLOW}${BOLD}Select an option (1-8): ${NC}"
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
                update_singbox
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
                clear
                print_header
                check_config
                ;;
            8)
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
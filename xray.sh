#!/bin/bash
# Xray Management Script for Ubuntu 24.04 / Debian 12
# This script helps manage Xray installation and configuration

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration paths
XRAY_CONFIG_PATH="/usr/local/etc/xray/config.json"
XRAY_BINARY="/usr/local/bin/xray"
INSTALL_SCRIPT_URL="https://github.com/XTLS/Xray-install/raw/main/install-release.sh"
BACKUP_DIR="/usr/local/etc/xray/backups"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if running with sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        print_color $RED "This script needs to be run with sudo privileges."
        print_color $YELLOW "Please run: sudo $0"
        exit 1
    fi
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    print_color $CYAN "Checking dependencies..."
    
    # Check for required commands
    for cmd in curl systemctl openssl nano jq; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=($cmd)
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_color $RED "Missing dependencies: ${missing_deps[*]}"
        print_color $YELLOW "Installing missing dependencies..."
        
        # Update package list
        apt-get update -qq
        
        # Install missing dependencies
        for dep in "${missing_deps[@]}"; do
            print_color $CYAN "Installing $dep..."
            apt-get install -y $dep
            if [ $? -ne 0 ]; then
                print_color $RED "Failed to install $dep"
                exit 1
            fi
        done
        print_color $GREEN "All dependencies installed successfully!"
    else
        print_color $GREEN "All dependencies are satisfied."
    fi
}

# Function to check if Xray is installed
is_xray_installed() {
    if [ -f "$XRAY_BINARY" ] && systemctl list-unit-files | grep -q "xray.service"; then
        return 0
    else
        return 1
    fi
}

# Function to validate config with detailed error reporting
validate_config_detailed() {
    local config_file="$1"
    local temp_error="/tmp/xray-error-$$.log"
    
    echo
    print_color $CYAN "    🔍 Validating configuration..."
    echo
    
    # First check JSON syntax with jq
    local json_error=$(jq empty "$config_file" 2>&1)
    if [ $? -ne 0 ]; then
        print_color $RED "    ❌ JSON syntax error detected:"
        echo
        print_color $YELLOW "    ━━━ JSON SYNTAX ERROR ━━━"
        echo
        
        # Parse and display JSON errors
        echo "$json_error" | while IFS= read -r line; do
            if echo "$line" | grep -q "line"; then
                print_color $YELLOW "    ► $line"
            else
                print_color $RED "    ► $line"
            fi
        done
        echo
        
        # Provide helpful hints
        if echo "$json_error" | grep -q "Expected.*but got"; then
            print_color $PURPLE "    💡 Hint: Check for missing or extra commas"
        elif echo "$json_error" | grep -q "Unexpected end"; then
            print_color $PURPLE "    💡 Hint: Missing closing bracket } or ]"
        elif echo "$json_error" | grep -q "Invalid"; then
            print_color $PURPLE "    💡 Hint: Check quotes and special characters"
        fi
        echo
        print_color $YELLOW "    ━━━━━━━━━━━━━━━━━━━━━━━"
        echo
        rm -f "$temp_error"
        return 1
    fi
    
    # Then check Xray-specific configuration
    if $XRAY_BINARY run -test -config "$config_file" > "$temp_error" 2>&1; then
        print_color $GREEN "    ✅ Configuration is valid!"
        rm -f "$temp_error"
        return 0
    else
        print_color $RED "    ❌ Xray configuration error:"
        echo
        print_color $YELLOW "    ━━━ XRAY CONFIG ERROR ━━━"
        echo
        
        # Display Xray-specific errors
        while IFS= read -r line; do
            # Highlight specific error types
            if echo "$line" | grep -qi "error\|failed\|invalid"; then
                print_color $RED "    ► $line"
            elif echo "$line" | grep -qi "warning"; then
                print_color $YELLOW "    ► $line"
            else
                print_color $CYAN "      $line"
            fi
        done < "$temp_error"
        
        echo
        print_color $YELLOW "    ━━━━━━━━━━━━━━━━━━━━━━━"
        echo
        
        # Provide Xray-specific hints
        if grep -qi "port" "$temp_error" 2>/dev/null; then
            print_color $PURPLE "    💡 Hint: Check if the port is already in use or invalid (1-65535)"
        elif grep -qi "uuid" "$temp_error" 2>/dev/null; then
            print_color $PURPLE "    💡 Hint: Invalid UUID format. Use 'Generate configuration data' option"
        elif grep -qi "protocol" "$temp_error" 2>/dev/null; then
            print_color $PURPLE "    💡 Hint: Invalid protocol. Common ones: vmess, vless, trojan, shadowsocks"
        elif grep -qi "address" "$temp_error" 2>/dev/null; then
            print_color $PURPLE "    💡 Hint: Invalid address format or domain name"
        fi
        
        rm -f "$temp_error"
        echo
        return 1
    fi
}

# Function to create automatic backup
create_auto_backup() {
    local config_file="$1"
    local backup_type="${2:-auto}"  # auto or manual
    
    if [ ! -f "$config_file" ]; then
        return 1
    fi
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Generate backup filename with timestamp
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$BACKUP_DIR/config_${backup_type}_${timestamp}.json"
    
    cp "$config_file" "$backup_file"
    if [ $? -eq 0 ]; then
        # Keep only the last 10 backups of each type
        cd "$BACKUP_DIR"
        ls -t config_${backup_type}_*.json 2>/dev/null | tail -n +11 | xargs -r rm
        echo "$backup_file"
        return 0
    else
        return 1
    fi
}

# Enhanced edit config function with auto-backup and detailed error reporting
edit_config() {
    if ! is_xray_installed; then
        print_color $RED "    ❌ Xray is not installed. Please install it first."
        return
    fi
    
    if [ ! -f "$XRAY_CONFIG_PATH" ]; then
        print_color $RED "    ❌ Configuration file not found at $XRAY_CONFIG_PATH"
        return
    fi
    
    echo
    print_color $CYAN "    📝 Opening Xray configuration file..."
    echo
    
    # Auto-create backup before editing
    print_color $CYAN "    💾 Creating automatic backup..."
    backup_file=$(create_auto_backup "$XRAY_CONFIG_PATH" "auto")
    if [ $? -eq 0 ]; then
        print_color $GREEN "    ✅ Backup saved: $(basename $backup_file)"
    else
        print_color $YELLOW "    ⚠️  Failed to create backup, proceeding anyway..."
    fi
    echo
    
    print_color $YELLOW "    ╔═══════════════════════════════════════════════════╗"
    print_color $GREEN "    ║                                                   ║"
    print_color $GREEN "    ║   💾 TO SAVE AND EXIT:     Ctrl+X → Y → Enter   ║"
    print_color $GREEN "    ║                                                   ║"
    print_color $RED "    ║   ❌ TO EXIT WITHOUT SAVE: Ctrl+X → N           ║"
    print_color $GREEN "    ║                                                   ║"
    print_color $YELLOW "    ╚═══════════════════════════════════════════════════╝"
    echo
    
    read -p "    Press Enter to open editor..."
    
    # Create a temporary copy for editing
    temp_config="/tmp/xray_config_edit_$$.json"
    cp "$XRAY_CONFIG_PATH" "$temp_config"
    
    nano "$temp_config"
    
    # Check if file was modified
    if cmp -s "$XRAY_CONFIG_PATH" "$temp_config"; then
        print_color $YELLOW "    ℹ️  No changes detected."
        rm -f "$temp_config"
        return
    fi
    
    # Validate the edited configuration
    if validate_config_detailed "$temp_config"; then
        # Config is valid, apply it
        cp "$temp_config" "$XRAY_CONFIG_PATH"
        rm -f "$temp_config"
        
        echo
        read -p "    🔄 Restart Xray to apply changes? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_color $CYAN "    🔄 Restarting Xray service..."
            systemctl restart xray
            sleep 2
            
            if systemctl is-active --quiet xray; then
                print_color $GREEN "    ✅ Service restarted successfully!"
                echo
                print_color $CYAN "    📊 Current Status:"
                systemctl status xray --no-pager | head -10
            else
                print_color $RED "    ❌ Service failed to start!"
                echo
                print_color $YELLOW "    ━━━ SERVICE ERROR LOGS ━━━"
                echo
                journalctl -u xray --no-pager -n 20 | tail -15
                echo
                print_color $YELLOW "    ━━━━━━━━━━━━━━━━━━━━━━━"
                echo
                
                read -p "    Restore previous configuration? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    cp "$backup_file" "$XRAY_CONFIG_PATH"
                    systemctl restart xray
                    print_color $GREEN "    ✅ Previous configuration restored"
                fi
            fi
        else
            print_color $GREEN "    ✅ Configuration saved. Remember to restart Xray later."
        fi
    else
        # Config has errors
        rm -f "$temp_config"
        echo
        read -p "    Do you want to fix the errors now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_color $CYAN "    📝 Opening editor to fix errors..."
            print_color $YELLOW "    ⚠️  Pay attention to the error details shown above"
            echo
            read -p "    Press Enter to continue..."
            
            # Re-edit the original file since temp was deleted
            edit_config  # Recursive call
        else
            read -p "    Restore backup configuration? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cp "$backup_file" "$XRAY_CONFIG_PATH"
                print_color $GREEN "    ✅ Backup restored"
            else
                print_color $YELLOW "    ⚠️  Configuration remains unchanged (with original content)"
            fi
        fi
    fi
}

# Function to install Xray
install_xray() {
    if is_xray_installed; then
        print_color $YELLOW "Xray is already installed."
        read -p "Do you want to reinstall? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    print_color $CYAN "Installing Xray using official script..."
    
    # Download and run the official installation script
    bash -c "$(curl -L $INSTALL_SCRIPT_URL)" @ install
    
    if [ $? -eq 0 ]; then
        print_color $GREEN "Xray installed successfully!"
        
        # Create a basic config if it doesn't exist
        if [ ! -f "$XRAY_CONFIG_PATH" ]; then
            print_color $YELLOW "Creating default configuration file..."
            mkdir -p $(dirname "$XRAY_CONFIG_PATH")
            cat > "$XRAY_CONFIG_PATH" << 'EOL'
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOL
            print_color $GREEN "Default configuration created at $XRAY_CONFIG_PATH"
        fi
    else
        print_color $RED "Failed to install Xray"
        print_color $YELLOW "Please check your internet connection and try again"
    fi
}

# Function to uninstall Xray
uninstall_xray() {
    if ! is_xray_installed; then
        print_color $YELLOW "Xray is not installed."
        return
    fi
    
    print_color $RED "WARNING: This will completely remove Xray from your system."
    read -p "Are you sure you want to uninstall Xray? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Create final backup before uninstalling
        if [ -f "$XRAY_CONFIG_PATH" ]; then
            print_color $CYAN "Creating final backup before uninstall..."
            final_backup=$(create_auto_backup "$XRAY_CONFIG_PATH" "uninstall")
            if [ $? -eq 0 ]; then
                print_color $GREEN "Final backup saved: $(basename $final_backup)"
            fi
        fi
        
        print_color $CYAN "Uninstalling Xray..."
        
        # Stop the service first
        systemctl stop xray 2>/dev/null
        systemctl disable xray 2>/dev/null
        
        # Run the official uninstall command
        bash -c "$(curl -L $INSTALL_SCRIPT_URL)" @ remove
        
        if [ $? -eq 0 ]; then
            print_color $GREEN "Xray uninstalled successfully!"
            print_color $YELLOW "Note: Configuration backups are preserved in $BACKUP_DIR"
        else
            print_color $RED "Failed to uninstall Xray"
        fi
    else
        print_color $YELLOW "Uninstall cancelled."
    fi
}

# Function to generate config data
generate_config_data() {
    echo
    print_color $BOLD "    🔐 XRAY CONFIGURATION DATA GENERATOR"
    print_color $PURPLE "    ══════════════════════════════════════════════════"
    echo
    
    # Generate random port
    print_color $YELLOW "    📡 Random Internal Port (1024-65535)"
    port=$(shuf -i 1024-65535 -n 1)
    print_color $GREEN "    ➜ $port"
    echo
    
    # Generate VLESS UUID
    print_color $YELLOW "    🔑 VLESS UUID"
    if command -v $XRAY_BINARY &> /dev/null; then
        uuid=$($XRAY_BINARY uuid)
        print_color $GREEN "    ➜ $uuid"
    else
        print_color $RED "    ⚠️  Xray not installed. Using fallback UUID generation."
        uuid=$(cat /proc/sys/kernel/random/uuid)
        print_color $GREEN "    ➜ $uuid"
    fi
    echo
    
    # Generate x25519 keys
    print_color $YELLOW "    🔐 x25519 Keys"
    if command -v $XRAY_BINARY &> /dev/null; then
        keys=$($XRAY_BINARY x25519)
        echo "$keys" | while IFS= read -r line; do
            print_color $GREEN "    ➜ $line"
        done
    else
        print_color $RED "    ⚠️  Xray not installed. Cannot generate x25519 keys."
    fi
    echo
    
    # Generate ShortId
    print_color $YELLOW "    🎲 ShortId (12 chars)"
    shortid=$(openssl rand -hex 6)
    print_color $GREEN "    ➜ $shortid"
    echo
    
    print_color $PURPLE "    ══════════════════════════════════════════════════"
    echo
}

# Function to restart Xray with validation
restart_xray() {
    if ! is_xray_installed; then
        print_color $RED "    ❌ Xray is not installed."
        return
    fi
    
    echo
    
    # Validate config before restart
    if ! validate_config_detailed "$XRAY_CONFIG_PATH"; then
        read -p "    Configuration has errors. Continue restart anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_color $YELLOW "    Restart cancelled."
            return
        fi
    fi
    
    print_color $CYAN "    🔄 Restarting Xray service..."
    systemctl restart xray
    sleep 2
    echo
    
    if systemctl is-active --quiet xray; then
        print_color $GREEN "    ✅ Service restarted successfully!"
        echo
        print_color $CYAN "    ═══════ XRAY STATUS ═══════"
        echo
        systemctl status xray --no-pager | head -10
    else
        print_color $RED "    ❌ Service failed to start!"
        echo
        print_color $YELLOW "    ━━━ ERROR LOGS ━━━"
        echo
        journalctl -u xray --no-pager -n 20 | tail -15
        echo
        print_color $YELLOW "    ━━━━━━━━━━━━━━━━━"
    fi
    echo
}

# Function to check Xray status
check_status() {
    if ! is_xray_installed; then
        print_color $RED "    ❌ Xray is not installed."
        return
    fi
    
    echo
    print_color $CYAN "    ═══════ XRAY SERVICE STATUS ═══════"
    echo
    systemctl status xray --no-pager
    echo
    echo
    print_color $CYAN "    ═══════ XRAY VERSION INFO ═══════"
    echo
    $XRAY_BINARY version
    echo
}

# Function to view Xray logs
view_logs() {
    if ! is_xray_installed; then
        print_color $RED "    ❌ Xray is not installed."
        return
    fi
    
    echo
    print_color $CYAN "    📜 Showing recent Xray logs"
    print_color $YELLOW "    💡 Press 'q' to quit and return to menu"
    echo
    sleep 2
    
    # Using --no-pager to allow immediate return to menu
    journalctl -u xray -n 50 --no-pager | less
}

# Function to update Xray
update_xray() {
    if ! is_xray_installed; then
        print_color $RED "Xray is not installed. Please install it first."
        return
    fi
    
    print_color $CYAN "Checking for Xray updates..."
    
    # Get current version
    current_version=$($XRAY_BINARY version | grep -oP 'Xray \K[\d.]+' | head -1)
    print_color $YELLOW "Current version: $current_version"
    
    # Backup config before update
    if [ -f "$XRAY_CONFIG_PATH" ]; then
        print_color $CYAN "Creating backup before update..."
        update_backup=$(create_auto_backup "$XRAY_CONFIG_PATH" "update")
        if [ $? -eq 0 ]; then
            print_color $GREEN "Backup saved: $(basename $update_backup)"
        fi
    fi
    
    # Update using official script
    print_color $CYAN "Updating Xray to the latest version..."
    bash -c "$(curl -L $INSTALL_SCRIPT_URL)" @ install
    
    if [ $? -eq 0 ]; then
        # Get new version
        new_version=$($XRAY_BINARY version | grep -oP 'Xray \K[\d.]+' | head -1)
        
        if [ "$current_version" != "$new_version" ]; then
            print_color $GREEN "Xray updated successfully! ($current_version → $new_version)"
            restart_xray
        else
            print_color $GREEN "Xray is already at the latest version ($current_version)"
        fi
    else
        print_color $RED "Failed to update Xray"
    fi
}

# Function to check configuration (new)
check_config() {
    if ! is_xray_installed; then
        print_color $RED "    ❌ Xray is not installed."
        return
    fi
    
    echo
    print_color $CYAN "    🔍 CHECKING XRAY CONFIGURATION"
    print_color $PURPLE "    ══════════════════════════════════════════════════"
    echo
    print_color $CYAN "    📁 Config file: $XRAY_CONFIG_PATH"
    
    if [ -f "$XRAY_CONFIG_PATH" ]; then
        # Get file info
        file_size=$(ls -lh "$XRAY_CONFIG_PATH" | awk '{print $5}')
        file_modified=$(stat -c %y "$XRAY_CONFIG_PATH" | cut -d'.' -f1)
        
        print_color $CYAN "    📏 Size: $file_size"
        print_color $CYAN "    📅 Modified: $file_modified"
        echo
        
        # Validate configuration
        validate_config_detailed "$XRAY_CONFIG_PATH"
        
        # Show config structure if jq is available
        if command -v jq >/dev/null 2>&1; then
            echo
            print_color $CYAN "    📋 Configuration Structure:"
            echo
            
            # Show main sections
            jq -r 'keys[]' "$XRAY_CONFIG_PATH" 2>/dev/null | while read -r key; do
                print_color $BOLD "      • $key"
                
                # Show sub-items for important sections
                case "$key" in
                    "inbounds")
                        count=$(jq ".inbounds | length" "$XRAY_CONFIG_PATH" 2>/dev/null)
                        print_color $GREEN "        └─ $count inbound(s) configured"
                        ;;
                    "outbounds")
                        count=$(jq ".outbounds | length" "$XRAY_CONFIG_PATH" 2>/dev/null)
                        print_color $GREEN "        └─ $count outbound(s) configured"
                        ;;
                esac
            done
        fi
    else
        print_color $RED "    ❌ Configuration file not found!"
    fi
    
    echo
    print_color $PURPLE "    ══════════════════════════════════════════════════"
    echo
}

# Function to display menu
show_menu() {
    clear
    echo
    print_color $BOLD "╔═══════════════════════════════════════════════════╗"
    print_color $BOLD "║                                                   ║"
    print_color $BOLD "║        🚀 XRAY MANAGEMENT SCRIPT 🚀                ║"
    print_color $BOLD "║                                                   ║"
    print_color $BOLD "╚═══════════════════════════════════════════════════╝"
    echo
    echo
    
    if is_xray_installed; then
        print_color $GREEN "    📊 Status: Xray is installed ✅"
        
        # Get Xray version if installed
        if [ -f "$XRAY_BINARY" ]; then
            version=$($XRAY_BINARY version 2>/dev/null | grep -oP 'Xray \K[\d.]+' | head -1)
            if [ -n "$version" ]; then
                print_color $GREEN "    📌 Version: $version"
            fi
        fi
        
        # Check service status
        if systemctl is-active --quiet xray; then
            print_color $GREEN "    🔄 Service: Running"
        else
            print_color $YELLOW "    ⚠️  Service: Stopped"
        fi
    else
        print_color $RED "    📊 Status: Xray is not installed ❌"
    fi
    
    echo
    echo
    print_color $YELLOW "    🔧 MAIN MENU OPTIONS:"
    echo
    echo
    print_color $CYAN "    1  ➜  Install Xray"
    echo
    print_color $CYAN "    2  ➜  Uninstall Xray"
    echo
    print_color $CYAN "    3  ➜  Edit Xray config (auto-backup)"
    echo
    print_color $CYAN "    4  ➜  Generate configuration data"
    echo
    print_color $CYAN "    5  ➜  Restart Xray service"
    echo
    print_color $CYAN "    6  ➜  Check Xray status"
    echo
    print_color $CYAN "    7  ➜  View Xray logs"
    echo
    print_color $CYAN "    8  ➜  Update Xray"
    echo
    print_color $CYAN "    9  ➜  Check configuration"
    echo
    print_color $CYAN "    0  ➜  Exit"
    echo
    echo
    print_color $WHITE "════════════════════════════════════════════════════"
    echo
}

# Main function
main() {
    check_sudo
    check_dependencies
    
    while true; do
        show_menu
        read -p "    🎯 Enter your choice [0-9]: " choice
        echo
        
        case $choice in
            1)
                install_xray
                ;;
            2)
                uninstall_xray
                ;;
            3)
                edit_config
                ;;
            4)
                generate_config_data
                ;;
            5)
                restart_xray
                ;;
            6)
                check_status
                ;;
            7)
                view_logs
                ;;
            8)
                update_xray
                ;;
            9)
                check_config
                ;;
            0)
                echo
                print_color $GREEN "    👋 Exiting... Goodbye!"
                echo
                exit 0
                ;;
            *)
                print_color $RED "    ❌ Invalid option. Please try again."
                ;;
        esac
        echo
        echo
        read -p "    Press Enter to continue..."
    done
}

# Run the main function
main

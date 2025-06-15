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
    for cmd in curl systemctl openssl nano; do
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
        print_color $CYAN "Uninstalling Xray..."
        
        # Stop the service first
        systemctl stop xray 2>/dev/null
        systemctl disable xray 2>/dev/null
        
        # Run the official uninstall command
        bash -c "$(curl -L $INSTALL_SCRIPT_URL)" @ remove
        
        if [ $? -eq 0 ]; then
            print_color $GREEN "Xray uninstalled successfully!"
        else
            print_color $RED "Failed to uninstall Xray"
        fi
    else
        print_color $YELLOW "Uninstall cancelled."
    fi
}

# Function to edit Xray config
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
    print_color $YELLOW "    ╔═══════════════════════════════════════════════════╗"
    print_color $GREEN "    ║                                                   ║"
    print_color $GREEN "    ║   💾 TO SAVE AND EXIT:     Ctrl+X → Y → Enter   ║"
    print_color $GREEN "    ║                                                   ║"
    print_color $RED "    ║   ❌ TO EXIT WITHOUT SAVE: Ctrl+X → N           ║"
    print_color $GREEN "    ║                                                   ║"
    print_color $CYAN "    ║   🗑️  TO DELETE ALL (Mac): ⌥+\ → Ctrl+6 →      ║"
    print_color $CYAN "    ║                           ⌥+/ → Ctrl+K         ║"
    print_color $GREEN "    ║                                                   ║"
    print_color $YELLOW "    ╚═══════════════════════════════════════════════════╝"
    echo
    echo
    
    # Ask about backup
    read -p "    💾 Create backup before editing? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        backup_config
        echo
    fi
    
    read -p "    Press Enter to open editor..."
    
    nano "$XRAY_CONFIG_PATH"
    
    # Validate JSON after editing
    echo
    print_color $CYAN "    🔍 Validating configuration..."
    if $XRAY_BINARY run -test -config "$XRAY_CONFIG_PATH" &>/dev/null; then
        print_color $GREEN "    ✅ Configuration is valid!"
        echo
        read -p "    🔄 Restart Xray to apply changes? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            restart_xray
        fi
    else
        print_color $RED "    ❌ Configuration validation failed!"
        print_color $YELLOW "    ⚠️  Please check your configuration for errors:"
        echo
        $XRAY_BINARY run -test -config "$XRAY_CONFIG_PATH"
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

# Function to restart Xray
restart_xray() {
    if ! is_xray_installed; then
        print_color $RED "    ❌ Xray is not installed."
        return
    fi
    
    echo
    print_color $CYAN "    🔄 Restarting Xray service..."
    systemctl restart xray
    sleep 2
    
    echo
    print_color $CYAN "    ═══════ XRAY STATUS ═══════"
    echo
    systemctl status xray --no-pager
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

# Function to backup config
backup_config() {
    if ! is_xray_installed; then
        print_color $RED "    ❌ Xray is not installed."
        return
    fi
    
    if [ ! -f "$XRAY_CONFIG_PATH" ]; then
        print_color $RED "    ❌ Configuration file not found."
        return
    fi
    
    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Generate backup filename with timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    backup_file="$BACKUP_DIR/config_backup_$timestamp.json"
    
    print_color $CYAN "    📦 Creating backup..."
    cp "$XRAY_CONFIG_PATH" "$backup_file"
    
    if [ $? -eq 0 ]; then
        print_color $GREEN "    ✅ Backup created successfully!"
        print_color $YELLOW "    📁 Location: $backup_file"
        
        # Keep only the last 10 backups
        cd "$BACKUP_DIR"
        ls -t config_backup_*.json 2>/dev/null | tail -n +11 | xargs -r rm
        
        # Show existing backups
        echo
        print_color $CYAN "    📋 Recent backups:"
        ls -lh "$BACKUP_DIR"/config_backup_*.json 2>/dev/null | tail -5 | while read line; do
            echo "       $line"
        done
    else
        print_color $RED "    ❌ Failed to create backup"
    fi
}

# Function to restore config
restore_config() {
    if ! is_xray_installed; then
        print_color $RED "    ❌ Xray is not installed."
        return
    fi
    
    # Check if backup directory exists and has backups
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR/config_backup_*.json 2>/dev/null)" ]; then
        print_color $RED "    ❌ No backups found."
        return
    fi
    
    print_color $CYAN "    📋 Available backups:"
    echo
    
    # List backups with numbers
    backups=($(ls -t "$BACKUP_DIR"/config_backup_*.json 2>/dev/null))
    for i in "${!backups[@]}"; do
        backup_file="${backups[$i]}"
        file_date=$(stat -c %y "$backup_file" 2>/dev/null | cut -d' ' -f1,2 | cut -d'.' -f1)
        file_size=$(ls -lh "$backup_file" | awk '{print $5}')
        printf "       %2d) %s (Size: %s)\n" $((i+1)) "$(basename $backup_file)" "$file_size"
        printf "           Created: %s\n\n" "$file_date"
    done
    
    echo
    read -p "    Enter backup number to restore (or 0 to cancel): " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#backups[@]}" ]; then
        selected_backup="${backups[$((choice-1))]}"
        
        # Create a backup of current config before restoring
        print_color $YELLOW "    💾 Backing up current config before restore..."
        timestamp=$(date +"%Y%m%d_%H%M%S")
        cp "$XRAY_CONFIG_PATH" "$BACKUP_DIR/config_before_restore_$timestamp.json"
        
        # Restore the selected backup
        print_color $CYAN "    📥 Restoring backup..."
        cp "$selected_backup" "$XRAY_CONFIG_PATH"
        
        if [ $? -eq 0 ]; then
            # Validate the restored config
            if $XRAY_BINARY run -test -config "$XRAY_CONFIG_PATH" &>/dev/null; then
                print_color $GREEN "    ✅ Config restored successfully!"
                read -p "    Restart Xray to apply changes? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    restart_xray
                fi
            else
                print_color $RED "    ❌ Restored config is invalid!"
                print_color $YELLOW "    🔄 Rolling back to previous config..."
                cp "$BACKUP_DIR/config_before_restore_$timestamp.json" "$XRAY_CONFIG_PATH"
            fi
        else
            print_color $RED "    ❌ Failed to restore backup"
        fi
    elif [ "$choice" -eq 0 ]; then
        print_color $YELLOW "    ❌ Restore cancelled."
    else
        print_color $RED "    ❌ Invalid selection."
    fi
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
    print_color $CYAN "    3  ➜  Edit Xray config file"
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
    print_color $CYAN "    9  ➜  Backup config"
    echo
    print_color $CYAN "    10 ➜  Restore config"
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
        read -p "    🎯 Enter your choice [0-10]: " choice
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
                backup_config
                ;;
            10)
                restore_config
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
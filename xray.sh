#!/bin/bash

# Enhanced Xray Management Script for Ubuntu 24.04 / Debian 12
# This script helps manage Xray installation and configuration
# Now with Quick Setup feature for easy VLESS-Reality deployment

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
    
    # Check for qrencode (for QR code generation)
    if ! command -v qrencode &> /dev/null; then
        missing_deps+=("qrencode")
    fi
    
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

# Function to get server's public IP
get_public_ip() {
    local ip=""
    # Try multiple services to get public IP
    ip=$(curl -s -4 https://api.ipify.org 2>/dev/null)
    if [ -z "$ip" ]; then
        ip=$(curl -s -4 https://icanhazip.com 2>/dev/null)
    fi
    if [ -z "$ip" ]; then
        ip=$(curl -s -4 https://checkip.amazonaws.com 2>/dev/null)
    fi
    echo "$ip"
}

# Function for Quick Setup - New Feature!
quick_setup() {
    echo
    print_color $BOLD "╔═══════════════════════════════════════════════════╗"
    print_color $BOLD "║        🚀 XRAY QUICK SETUP WIZARD 🚀              ║"
    print_color $BOLD "╚═══════════════════════════════════════════════════╝"
    echo
    
    # Check if Xray is installed
    if ! is_xray_installed; then
        print_color $YELLOW "Xray is not installed. Installing now..."
        install_xray_silent
        if ! is_xray_installed; then
            print_color $RED "Failed to install Xray. Please try manual installation."
            return 1
        fi
    fi
    
    # Step 1: Choose port
    echo
    print_color $CYAN "📡 STEP 1: Choose Server Port"
    print_color $WHITE "Common ports for better connectivity:"
    echo
    echo "    1) 443  (HTTPS standard)"
    echo "    2) 8443 (Alternative HTTPS)"
    echo "    3) 9443 (Another alternative)"
    echo "    4) Custom port"
    echo
    read -p "    Select option [1-4]: " port_choice
    
    case $port_choice in
        1) server_port=443 ;;
        2) server_port=8443 ;;
        3) server_port=9443 ;;
        4) 
            read -p "    Enter custom port (1024-65535): " server_port
            # Validate port
            if ! [[ "$server_port" =~ ^[0-9]+$ ]] || [ "$server_port" -lt 1024 ] || [ "$server_port" -gt 65535 ]; then
                print_color $RED "    Invalid port number. Using default 8443."
                server_port=8443
            fi
            ;;
        *) 
            print_color $YELLOW "    Invalid choice. Using default port 8443."
            server_port=8443
            ;;
    esac
    
    print_color $GREEN "    ✓ Selected port: $server_port"
    
    # Step 2: Choose target website
    echo
    print_color $CYAN "🌐 STEP 2: Choose Target Website (for REALITY)"
    print_color $WHITE "Recommended sites with good TLS 1.3 support:"
    echo
    echo "    1) www.tesla.com"
    echo "    2) www.icloud.com"
    echo "    3) Custom website"
    echo
    read -p "    Select option [1-3]: " site_choice
    
    case $site_choice in
        1) target_site="www.tesla.com" ;;
        2) target_site="www.icloud.com" ;;
        3) 
            read -p "    Enter custom website (e.g., www.example.com): " target_site
            # Basic validation
            if [[ ! "$target_site" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                print_color $RED "    Invalid website format. Using default www.tesla.com"
                target_site="www.tesla.com"
            fi
            ;;
        *) 
            print_color $YELLOW "    Invalid choice. Using default www.tesla.com"
            target_site="www.tesla.com"
            ;;
    esac
    
    print_color $GREEN "    ✓ Selected target: $target_site"
    
    # Step 3: Get server IP
    echo
    print_color $CYAN "🌍 STEP 3: Server IP Address"
    server_ip=$(get_public_ip)
    if [ -n "$server_ip" ]; then
        print_color $GREEN "    ✓ Detected IP: $server_ip"
        read -p "    Use this IP? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            read -p "    Enter server IP: " server_ip
        fi
    else
        print_color $YELLOW "    Could not auto-detect IP."
        read -p "    Enter server IP: " server_ip
    fi
    
    # Step 4: Optional - Dokodemo-door configuration
    echo
    print_color $CYAN "🔗 STEP 4: Advanced Options (Optional)"
    read -p "    Add Dokodemo-door for proxy chaining? (y/n): " -n 1 -r
    echo
    dokodemo_enabled=false
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        dokodemo_enabled=true
        read -p "    Enter Dokodemo local port (e.g., 1080): " dokodemo_port
        read -p "    Enter remote server address: " dokodemo_address
        read -p "    Enter remote server port: " dokodemo_remote_port
    fi
    
    # Generate configuration data
    echo
    print_color $CYAN "🔐 Generating configuration..."
    
    # Generate UUID
    uuid=$($XRAY_BINARY uuid)
    
    # Generate x25519 keys
    keys=$($XRAY_BINARY x25519)
    private_key=$(echo "$keys" | grep "Private key:" | cut -d' ' -f3)
    public_key=$(echo "$keys" | grep "Public key:" | cut -d' ' -f3)
    
    # Generate short ID
    short_id=$(openssl rand -hex 8)
    
    # Create configuration
    if [ "$dokodemo_enabled" = true ]; then
        # Configuration with dokodemo-door
        cat > "$XRAY_CONFIG_PATH" << EOF
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "tag": "dokodemo-in",
            "port": $dokodemo_port,
            "protocol": "dokodemo-door",
            "settings": {
                "address": "$dokodemo_address",
                "port": $dokodemo_remote_port,
                "network": "tcp,udp",
                "followRedirect": false,
                "userLevel": 0
            }
        },
        {
            "port": $server_port,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "dest": "$target_site:443",
                    "serverNames": [
                        "$target_site"
                    ],
                    "privateKey": "$private_key",
                    "shortIds": [
                        "$short_id"
                    ]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ],
                "routeOnly": true
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
}
EOF
    else
        # Simple configuration without dokodemo-door
        cat > "$XRAY_CONFIG_PATH" << EOF
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": $server_port,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "$uuid",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "dest": "$target_site:443",
                    "serverNames": [
                        "$target_site"
                    ],
                    "privateKey": "$private_key",
                    "shortIds": [
                        "$short_id"
                    ]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": [
                    "http",
                    "tls",
                    "quic"
                ],
                "routeOnly": true
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
}
EOF
    fi
    
    # Validate configuration
    print_color $CYAN "    🔍 Validating configuration..."
    if $XRAY_BINARY run -test -config "$XRAY_CONFIG_PATH" &>/dev/null; then
        print_color $GREEN "    ✅ Configuration is valid!"
    else
        print_color $RED "    ❌ Configuration validation failed!"
        return 1
    fi
    
    # Restart Xray
    print_color $CYAN "    🔄 Restarting Xray service..."
    systemctl restart xray
    sleep 2
    
    if systemctl is-active --quiet xray; then
        print_color $GREEN "    ✅ Xray is running!"
    else
        print_color $RED "    ❌ Xray failed to start!"
        return 1
    fi
    
    # Generate VLESS URI
    vless_uri="vless://${uuid}@${server_ip}:${server_port}?security=reality&encryption=none&pbk=${public_key}&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=${target_site}&sid=${short_id}#Xray-Reality"
    
    # Display results
    echo
    echo
    print_color $BOLD "╔═══════════════════════════════════════════════════╗"
    print_color $BOLD "║           ✅ SETUP COMPLETED!                     ║"
    print_color $BOLD "╚═══════════════════════════════════════════════════╝"
    echo
    print_color $CYAN "📋 Configuration Details:"
    echo
    print_color $WHITE "    Server IP:     $server_ip"
    print_color $WHITE "    Port:          $server_port"
    print_color $WHITE "    Target Site:   $target_site"
    print_color $WHITE "    UUID:          $uuid"
    print_color $WHITE "    Public Key:    $public_key"
    print_color $WHITE "    Short ID:      $short_id"
    
    if [ "$dokodemo_enabled" = true ]; then
        echo
        print_color $CYAN "    🔗 Dokodemo-door:"
        print_color $WHITE "    Local Port:    $dokodemo_port"
        print_color $WHITE "    Remote:        $dokodemo_address:$dokodemo_remote_port"
    fi
    
    echo
    print_color $CYAN "📱 VLESS Connection URI:"
    echo
    print_color $YELLOW "    $vless_uri"
    echo
    echo
    print_color $CYAN "📱 QR Code (scan with your app):"
    echo
    
    # Generate QR code in terminal
    qrencode -t utf8 "$vless_uri"
    
    echo
    read -p "    💾 Save QR code as image? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        qr_filename="xray_qr_$(date +%Y%m%d_%H%M%S).png"
        qrencode -o "$qr_filename" -s 10 "$vless_uri"
        print_color $GREEN "    ✅ QR code saved as: $qr_filename"
    fi
    
    echo
    print_color $GREEN "🎉 Setup complete! Copy the URI above or scan the QR code with your client app."
    echo
}

# Silent Xray installation for quick setup
install_xray_silent() {
    bash -c "$(curl -L $INSTALL_SCRIPT_URL)" @ install &>/dev/null
    return $?
}

# Original install_xray function (kept for manual installation)
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
    print_color $YELLOW "    🎲 ShortId (16 chars)"
    shortid=$(openssl rand -hex 8)
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
                print_
#!/bin/bash

# Xray Quick Setup Script - Standalone Version
# This is a simplified version focused only on quick setup

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration paths
XRAY_CONFIG_PATH="/usr/local/etc/xray/config.json"
XRAY_BINARY="/usr/local/bin/xray"
INSTALL_SCRIPT_URL="https://github.com/XTLS/Xray-install/raw/main/install-release.sh"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    print_color $RED "This script needs to be run with sudo privileges."
    print_color $YELLOW "Please run: sudo $0"
    exit 1
fi

# Install dependencies if needed
print_color $CYAN "Checking dependencies..."
for cmd in curl systemctl openssl qrencode; do
    if ! command -v $cmd &> /dev/null; then
        print_color $YELLOW "Installing $cmd..."
        apt-get update -qq
        apt-get install -y $cmd
    fi
done
print_color $GREEN "All dependencies satisfied!"

# Check if Xray is installed
if [ ! -f "$XRAY_BINARY" ]; then
    print_color $YELLOW "Installing Xray..."
    bash -c "$(curl -L $INSTALL_SCRIPT_URL)" @ install
    if [ $? -ne 0 ]; then
        print_color $RED "Failed to install Xray!"
        exit 1
    fi
fi

# Get public IP
get_public_ip() {
    local ip=""
    ip=$(curl -s -4 https://api.ipify.org 2>/dev/null)
    if [ -z "$ip" ]; then
        ip=$(curl -s -4 https://icanhazip.com 2>/dev/null)
    fi
    echo "$ip"
}

clear
echo
print_color $BOLD "╔═══════════════════════════════════════════════════╗"
print_color $BOLD "║        🚀 XRAY QUICK SETUP WIZARD 🚀              ║"
print_color $BOLD "╚═══════════════════════════════════════════════════╝"
echo

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
mkdir -p $(dirname "$XRAY_CONFIG_PATH")
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

# Validate configuration
print_color $CYAN "    🔍 Validating configuration..."
if $XRAY_BINARY run -test -config "$XRAY_CONFIG_PATH" &>/dev/null; then
    print_color $GREEN "    ✅ Configuration is valid!"
else
    print_color $RED "    ❌ Configuration validation failed!"
    exit 1
fi

# Restart Xray
print_color $CYAN "    🔄 Restarting Xray service..."
systemctl restart xray
sleep 2

if systemctl is-active --quiet xray; then
    print_color $GREEN "    ✅ Xray is running!"
else
    print_color $RED "    ❌ Xray failed to start!"
    exit 1
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

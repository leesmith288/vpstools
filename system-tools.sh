#!/bin/bash

# VPS System Tools Management Script
# Author: Automated Script Generator
# Date: 2025-06-08
# Description: Comprehensive VPS management tool for Debian 12 and Ubuntu 24.04

# Color definitions for myopia-friendly interface
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Log file
LOG_FILE="/var/log/vps-system-tools.log"

# Function to log actions
log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to print colored output
print_color() {
    echo -e "${1}${2}${NC}"
}

# Function to print headers
print_header() {
    echo
    print_color "$CYAN" "════════════════════════════════════════════════════════════════"
    print_color "$CYAN$BOLD" "  $1"
    print_color "$CYAN" "════════════════════════════════════════════════════════════════"
    echo
}

# Function to print success message
print_success() {
    print_color "$GREEN" "✅ $1"
}

# Function to print error message
print_error() {
    print_color "$RED" "❌ $1"
}

# Function to print warning message
print_warning() {
    print_color "$YELLOW" "⚠️  $1"
}

# Function to print info message
print_info() {
    print_color "$BLUE" "ℹ️  $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script requires root privileges."
        print_info "Please run: sudo $0"
        exit 1
    fi
}

# Function to detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS="$ID"
        OS_VERSION="$VERSION_ID"
        
        case $OS in
            "debian")
                if [[ "$OS_VERSION" == "12" ]]; then
                    print_success "Detected: Debian 12 (Bookworm)"
                    return 0
                else
                    print_warning "Detected: Debian $OS_VERSION (Script optimized for Debian 12)"
                fi
                ;;
            "ubuntu")
                if [[ "$OS_VERSION" == "24.04" ]]; then
                    print_success "Detected: Ubuntu 24.04 LTS"
                    return 0
                else
                    print_warning "Detected: Ubuntu $OS_VERSION (Script optimized for Ubuntu 24.04)"
                fi
                ;;
            *)
                print_error "Unsupported OS: $OS $OS_VERSION"
                print_info "This script is designed for Debian 12 or Ubuntu 24.04"
                exit 1
                ;;
        esac
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
}

# Function to check internet connectivity
check_internet() {
    print_info "Checking internet connectivity..."
    if ping -c 1 google.com &> /dev/null; then
        print_success "Internet connection verified"
    else
        print_error "No internet connection detected"
        exit 1
    fi
}

# Function to update package lists
update_packages() {
    print_info "Updating package lists..."
    if apt update &> /dev/null; then
        print_success "Package lists updated"
    else
        print_error "Failed to update package lists"
        exit 1
    fi
}

# Function to set timezone to Asia/Shanghai
set_timezone() {
    print_header "🌏 TIMEZONE CONFIGURATION"
    
    current_tz=$(timedatectl show --property=Timezone --value)
    print_info "Current timezone: $current_tz"
    
    if [[ "$current_tz" == "Asia/Shanghai" ]]; then
        print_success "Timezone is already set to Asia/Shanghai"
        read -p "Press Enter to continue..."
        return 0
    fi
    
    print_info "Setting timezone to Asia/Shanghai..."
    echo
    read -p "Do you want to change timezone to Asia/Shanghai? [Y/n]: " confirm
    
    if [[ $confirm =~ ^[Nn]$ ]]; then
        print_info "Timezone change cancelled"
        return 0
    fi
    
    if timedatectl set-timezone Asia/Shanghai; then
        new_tz=$(timedatectl show --property=Timezone --value)
        print_success "Timezone successfully changed to: $new_tz"
        print_info "Current time: $(date)"
        log_action "Timezone changed to Asia/Shanghai"
    else
        print_error "Failed to set timezone"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to get RAM size in GB
get_ram_size() {
    ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    ram_gb=$((ram_kb / 1024 / 1024))
    echo $ram_gb
}

# Function to calculate recommended swap size
calculate_swap_size() {
    ram_gb=$(get_ram_size)
    
    if [[ $ram_gb -le 2 ]]; then
        echo $((ram_gb * 2))
    elif [[ $ram_gb -le 8 ]]; then
        echo $ram_gb
    else
        echo 8
    fi
}

# Function to check existing swap
check_existing_swap() {
    existing_swap=$(swapon --show=NAME --noheadings)
    if [[ -n "$existing_swap" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to setup swap
setup_swap() {
    print_header "💾 SWAP MEMORY CONFIGURATION"
    
    ram_gb=$(get_ram_size)
    recommended_swap=$(calculate_swap_size)
    
    print_info "System RAM: ${ram_gb}GB"
    print_info "Recommended swap size: ${recommended_swap}GB"
    echo
    
    # Check existing swap
    if check_existing_swap; then
        print_warning "Existing swap detected:"
        swapon --show
        echo
        echo "Options:"
        echo "1) Replace existing swap"
        echo "2) Keep existing swap"
        echo "3) Return to main menu"
        echo
        read -p "Your choice [1-3]: " swap_choice
        
        case $swap_choice in
            1)
                print_info "Disabling existing swap..."
                swapoff -a
                print_success "Existing swap disabled"
                ;;
            2)
                print_info "Keeping existing swap configuration"
                read -p "Press Enter to continue..."
                return 0
                ;;
            3)
                return 0
                ;;
            *)
                print_error "Invalid choice"
                return 1
                ;;
        esac
    fi
    
    echo
    read -p "Enter swap size in GB (recommended: ${recommended_swap}GB) [${recommended_swap}]: " user_swap_size
    
    if [[ -z "$user_swap_size" ]]; then
        swap_size=$recommended_swap
    else
        swap_size=$user_swap_size
    fi
    
    # Validate input
    if ! [[ "$swap_size" =~ ^[0-9]+$ ]] || [[ $swap_size -lt 1 ]]; then
        print_error "Invalid swap size. Must be a positive integer."
        return 1
    fi
    
    print_warning "This will create a ${swap_size}GB swap file at /swapfile"
    read -p "Continue? [Y/n]: " confirm
    
    if [[ $confirm =~ ^[Nn]$ ]]; then
        print_info "Swap setup cancelled"
        return 0
    fi
    
    print_info "Creating ${swap_size}GB swap file... (This may take several minutes)"
    
    # Remove existing swapfile if exists
    if [[ -f /swapfile ]]; then
        rm -f /swapfile
    fi
    
    # Create swap file
    if dd if=/dev/zero of=/swapfile bs=1G count=$swap_size status=progress; then
        print_success "Swap file created"
    else
        print_error "Failed to create swap file"
        return 1
    fi
    
    # Set permissions
    chmod 600 /swapfile
    
    # Setup swap
    if mkswap /swapfile && swapon /swapfile; then
        print_success "Swap activated"
        
        # Add to fstab for persistence
        if ! grep -q "/swapfile" /etc/fstab; then
            echo "/swapfile none swap sw 0 0" >> /etc/fstab
            print_success "Swap added to /etc/fstab for persistence"
        fi
        
        # Show swap status
        echo
        print_info "Current swap status:"
        free -h | grep -E "Mem|Swap"
        
        log_action "Swap file created: ${swap_size}GB"
    else
        print_error "Failed to activate swap"
        return 1
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to check if package is installed
is_package_installed() {
    dpkg -l "$1" &> /dev/null
}

# Function to install Docker
install_docker() {
    print_header "🐳 DOCKER INSTALLATION"
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        docker_version=$(docker --version)
        print_success "Docker is already installed: $docker_version"
        read -p "Press Enter to continue..."
        return 0
    fi
    
    print_info "Installing Docker using official repository method..."
    print_info "Estimated time: 2-5 minutes"
    print_info "Estimated size: ~100-150 MB"
    echo
    
    read -p "Continue with Docker installation? [Y/n]: " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        return 0
    fi
    
    # Install prerequisites
    print_info "Installing prerequisites..."
    apt install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    print_info "Adding Docker GPG key..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    print_info "Adding Docker repository..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index
    apt update
    
    # Install Docker
    print_info "Installing Docker Engine..."
    if apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; then
        print_success "Docker installed successfully"
        
        # Start and enable Docker
        systemctl start docker
        systemctl enable docker
        print_success "Docker service started and enabled"
        
        # Add current user to docker group (if not root)
        if [[ "$SUDO_USER" ]]; then
            usermod -aG docker "$SUDO_USER"
            print_success "User $SUDO_USER added to docker group"
            print_warning "Please log out and log back in for group changes to take effect"
        fi
        
        # Show Docker version
        docker_version=$(docker --version)
        print_success "Installed: $docker_version"
        
        log_action "Docker installed successfully"
    else
        print_error "Failed to install Docker"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to install official Caddy
install_caddy_official() {
    print_info "Installing Official Caddy..."
    print_info "Estimated time: 1-2 minutes"
    print_info "Estimated size: ~50 MB"
    echo
    
    # Install prerequisites
    print_info "Installing prerequisites..."
    apt install -y debian-keyring debian-archive-keyring apt-transport-https
    
    # Add Caddy's official GPG key
    print_info "Adding Caddy GPG key..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    
    # Add Caddy repository
    print_info "Adding Caddy repository..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
    
    # Update package index
    apt update
    
    # Install Caddy
    print_info "Installing Caddy..."
    if apt install -y caddy; then
        print_success "Official Caddy installed successfully"
        
        # Start and enable Caddy
        systemctl start caddy
        systemctl enable caddy
        print_success "Caddy service started and enabled"
        
        # Show Caddy version
        caddy_version=$(caddy version)
        print_success "Installed: $caddy_version"
        
        # Show service status
        if systemctl is-active --quiet caddy; then
            print_success "Caddy service is running"
        else
            print_warning "Caddy service is not running"
        fi
        
        log_action "Official Caddy installed successfully"
    else
        print_error "Failed to install Caddy"
    fi
}

# Function to install Caddy with Cloudflare plugin
install_caddy_cloudflare() {
    print_info "Installing Caddy with Cloudflare DNS plugin..."
    print_info "This version includes the Cloudflare DNS challenge module for automatic HTTPS"
    print_info "Estimated time: 2-3 minutes"
    print_info "Estimated size: ~50-60 MB"
    echo
    
    # Install prerequisites
    print_info "Installing prerequisites..."
    apt install -y curl wget
    
    # Download Caddy with Cloudflare plugin from official build server
    print_info "Downloading Caddy with Cloudflare plugin..."
    
    # Determine architecture
    ARCH=$(dpkg --print-architecture)
    case $ARCH in
        amd64)
            CADDY_ARCH="amd64"
            ;;
        arm64)
            CADDY_ARCH="arm64"
            ;;
        armhf)
            CADDY_ARCH="armv7"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            return 1
            ;;
    esac
    
    # Download custom Caddy build with Cloudflare plugin
    DOWNLOAD_URL="https://caddyserver.com/api/download?os=linux&arch=${CADDY_ARCH}&p=github.com%2Fcaddy-dns%2Fcloudflare"
    
    print_info "Downloading from: $DOWNLOAD_URL"
    if wget -O /tmp/caddy.tar.gz "$DOWNLOAD_URL"; then
        print_success "Download completed"
    else
        print_error "Failed to download Caddy with Cloudflare plugin"
        return 1
    fi
    
    # Extract and install
    print_info "Extracting and installing Caddy..."
    cd /tmp
    tar -xzf caddy.tar.gz
    
    # Move binary to system location
    mv caddy /usr/bin/caddy
    chmod +x /usr/bin/caddy
    
    # Create caddy user if not exists
    if ! id -u caddy &>/dev/null; then
        useradd -r -d /var/lib/caddy -s /bin/false caddy
        print_success "Created caddy user"
    fi
    
    # Create necessary directories
    mkdir -p /etc/caddy
    mkdir -p /var/lib/caddy
    mkdir -p /var/log/caddy
    
    # Set permissions
    chown -R caddy:caddy /etc/caddy
    chown -R caddy:caddy /var/lib/caddy
    chown -R caddy:caddy /var/log/caddy
    
    # Create systemd service file
    print_info "Creating systemd service..."
    cat > /etc/systemd/system/caddy.service << 'EOF'
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/var/lib/caddy /var/log/caddy /etc/caddy
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF
    
    # Create default Caddyfile with Cloudflare example
    print_info "Creating example Caddyfile with Cloudflare configuration..."
    cat > /etc/caddy/Caddyfile << 'EOF'
# Example Caddyfile with Cloudflare DNS challenge
# Uncomment and modify the following lines to use Cloudflare DNS

# (cloudflare) {
#     tls {
#         dns cloudflare {env.CLOUDFLARE_API_TOKEN}
#     }
# }

# example.com {
#     import cloudflare
#     reverse_proxy localhost:8080
# }

# Default configuration
:80 {
    respond "Caddy with Cloudflare plugin is working!"
}
EOF
    
    # Reload systemd and start Caddy
    systemctl daemon-reload
    systemctl enable caddy
    systemctl start caddy
    
    # Verify installation
    if command -v caddy &> /dev/null; then
        caddy_version=$(caddy version)
        print_success "Caddy with Cloudflare plugin installed successfully"
        print_success "Version: $caddy_version"
        
        # Show service status
        if systemctl is-active --quiet caddy; then
            print_success "Caddy service is running"
        else
            print_warning "Caddy service is not running"
        fi
        
        print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_info "To use Cloudflare DNS challenge:"
        print_info "1. Get your Cloudflare API token from: https://dash.cloudflare.com/profile/api-tokens"
        print_info "2. Set the environment variable: export CLOUDFLARE_API_TOKEN='your-token'"
        print_info "3. Edit /etc/caddy/Caddyfile and uncomment the Cloudflare section"
        print_info "4. Reload Caddy: systemctl reload caddy"
        print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        log_action "Caddy with Cloudflare plugin installed successfully"
    else
        print_error "Failed to install Caddy with Cloudflare plugin"
        return 1
    fi
    
    # Clean up
    rm -f /tmp/caddy.tar.gz
}

# Function to install Caddy (main function with choice)
install_caddy() {
    print_header "🌐 CADDY INSTALLATION"
    
    # Check if Caddy is already installed
    if command -v caddy &> /dev/null; then
        caddy_version=$(caddy version)
        print_success "Caddy is already installed: $caddy_version"
        echo
        echo "Options:"
        echo "[1] Keep current installation"
        echo "[2] Reinstall/Replace with different version"
        echo
        read -p "Your choice [1-2]: " replace_choice
        
        if [[ "$replace_choice" == "1" ]]; then
            read -p "Press Enter to continue..."
            return 0
        elif [[ "$replace_choice" == "2" ]]; then
            print_info "Removing current Caddy installation..."
            systemctl stop caddy 2>/dev/null
            systemctl disable caddy 2>/dev/null
            apt remove --purge -y caddy 2>/dev/null
            rm -f /usr/bin/caddy 2>/dev/null
            print_success "Current Caddy installation removed"
        else
            print_error "Invalid choice"
            return 1
        fi
    fi
    
    echo "Select Caddy version to install:"
    echo
    print_color "$CYAN" "[1] 📦 Official Caddy (Standard version from official repository)"
    print_color "$CYAN" "[2] ☁️  Caddy with Cloudflare Plugin (For Cloudflare DNS challenge)"
    print_color "$CYAN" "[3] 🔙 Cancel and return to main menu"
    echo
    
    read -p "Your choice [1-3]: " caddy_choice
    
    case $caddy_choice in
        1)
            echo
            read -p "Continue with Official Caddy installation? [Y/n]: " confirm
            if [[ ! $confirm =~ ^[Nn]$ ]]; then
                install_caddy_official
            else
                print_info "Installation cancelled"
            fi
            ;;
        2)
            echo
            read -p "Continue with Caddy + Cloudflare plugin installation? [Y/n]: " confirm
            if [[ ! $confirm =~ ^[Nn]$ ]]; then
                install_caddy_cloudflare
            else
                print_info "Installation cancelled"
            fi
            ;;
        3)
            print_info "Returning to main menu..."
            return 0
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
}

# Function to show main menu with improved spacing for myopia users
show_main_menu() {
    clear
    
    # Add extra line breaks for better spacing
    echo
    echo
    
    # Title box with extra padding
    print_color "$PURPLE$BOLD" "╔════════════════════════════════════════════════════════════════════╗"
    print_color "$PURPLE$BOLD" "║                                                                    ║"
    print_color "$PURPLE$BOLD" "║                      🚀 VPS SYSTEM TOOLS 🚀                       ║"
    print_color "$PURPLE$BOLD" "║                                                                    ║"
    print_color "$PURPLE$BOLD" "║                    Management Script v1.0                         ║"
    print_color "$PURPLE$BOLD" "║                 Debian 12 / Ubuntu 24.04                          ║"
    print_color "$PURPLE$BOLD" "║                                                                    ║"
    print_color "$PURPLE$BOLD" "╚════════════════════════════════════════════════════════════════════╝"
    
    echo
    echo
    
    # System info with better spacing
    print_color "$WHITE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "  System: $OS $OS_VERSION  |  User: $(whoami)  |  Date: $(date '+%Y-%m-%d %H:%M')"
    print_color "$WHITE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo
    echo
    
    # Main menu title with extra spacing
    print_color "$WHITE$BOLD" "                        📋  MAIN MENU  📋"
    
    echo
    echo
    
    # Menu options with double line spacing
    print_color "$CYAN$BOLD" "     [1]  🌏  Set Timezone to Asia/Shanghai"
    echo
    
    print_color "$CYAN$BOLD" "     [2]  💾  Setup Swap Memory"
    echo
    
    print_color "$CYAN$BOLD" "     [3]  🐳  Install Docker"
    echo
    
    print_color "$CYAN$BOLD" "     [4]  🌐  Install Caddy"
    echo
    
    print_color "$CYAN$BOLD" "     [5]  📋  View System Information"
    echo
    
    print_color "$CYAN$BOLD" "     [6]  📄  View Log File"
    echo
    
    print_color "$CYAN$BOLD" "     [7]  ❌  Exit"
    
    echo
    echo
    print_color "$WHITE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
}

# Alternative version with even larger visual presentation
show_main_menu_large() {
    clear
    
    # Use printf for consistent spacing
    printf "\n\n\n"
    
    # Large title
    print_color "$PURPLE$BOLD" "╔══════════════════════════════════════════════════════════════════════════════╗"
    print_color "$PURPLE$BOLD" "║                                                                              ║"
    print_color "$PURPLE$BOLD" "║                         🚀  VPS SYSTEM TOOLS  🚀                             ║"
    print_color "$PURPLE$BOLD" "║                                                                              ║"
    print_color "$PURPLE$BOLD" "║                         Management Script v1.0                              ║"
    print_color "$PURPLE$BOLD" "║                                                                              ║"
    print_color "$PURPLE$BOLD" "╚══════════════════════════════════════════════════════════════════════════════╝"
    
    printf "\n\n"
    
    # System info bar
    print_color "$YELLOW$BOLD" "┌──────────────────────────────────────────────────────────────────────────────┐"
    print_color "$YELLOW$BOLD" "│   System: $OS $OS_VERSION    User: $(whoami)    Date: $(date '+%Y-%m-%d %H:%M')   │"
    print_color "$YELLOW$BOLD" "└──────────────────────────────────────────────────────────────────────────────┘"
    
    printf "\n\n\n"
    
    # Menu with large spacing
    print_color "$WHITE$BOLD" "                           SELECT AN OPTION:"
    printf "\n\n"
    
    # Each option on its own visual block
    print_color "$CYAN$BOLD" "        ┌─────────────────────────────────────────────┐"
    print_color "$CYAN$BOLD" "        │  [1]  🌏  Set Timezone to Asia/Shanghai    │"
    print_color "$CYAN$BOLD" "        └─────────────────────────────────────────────┘"
    printf "\n"
    
    print_color "$CYAN$BOLD" "        ┌─────────────────────────────────────────────┐"
    print_color "$CYAN$BOLD" "        │  [2]  💾  Setup Swap Memory                │"
    print_color "$CYAN$BOLD" "        └─────────────────────────────────────────────┘"
    printf "\n"
    
    print_color "$CYAN$BOLD" "        ┌─────────────────────────────────────────────┐"
    print_color "$CYAN$BOLD" "        │  [3]  🐳  Install Docker                   │"
    print_color "$CYAN$BOLD" "        └─────────────────────────────────────────────┘"
    printf "\n"
    
    print_color "$CYAN$BOLD" "        ┌─────────────────────────────────────────────┐"
    print_color "$CYAN$BOLD" "        │  [4]  🌐  Install Caddy                    │"
    print_color "$CYAN$BOLD" "        └─────────────────────────────────────────────┘"
    printf "\n"
    
    print_color "$CYAN$BOLD" "        ┌─────────────────────────────────────────────┐"
    print_color "$CYAN$BOLD" "        │  [5]  📋  View System Information          │"
    print_color "$CYAN$BOLD" "        └─────────────────────────────────────────────┘"
    printf "\n"
    
    print_color "$CYAN$BOLD" "        ┌─────────────────────────────────────────────┐"
    print_color "$CYAN$BOLD" "        │  [6]  📄  View Log File                    │"
    print_color "$CYAN$BOLD" "        └─────────────────────────────────────────────┘"
    printf "\n"
    
    print_color "$RED$BOLD" "        ┌─────────────────────────────────────────────┐"
    print_color "$RED$BOLD" "        │  [7]  ❌  Exit                             │"
    print_color "$RED$BOLD" "        └─────────────────────────────────────────────┘"
    
    printf "\n\n"
}

# Function to show system information
show_system_info() {
    print_header "💻 SYSTEM INFORMATION"
    
    echo "🖥️  Operating System:"
    echo "   OS: $OS $OS_VERSION"
    echo "   Kernel: $(uname -r)"
    echo "   Architecture: $(uname -m)"
    echo
    
    echo "💾 Memory Information:"
    free -h
    echo
    
    echo "💿 Disk Usage:"
    df -h /
    echo
    
    echo "🔄 Swap Information:"
    if check_existing_swap; then
        swapon --show
    else
        echo "   No swap configured"
    fi
    echo
    
    echo "🐳 Docker Status:"
    if command -v docker &> /dev/null; then
        docker --version
        if systemctl is-active --quiet docker; then
            echo "   Status: Running ✅"
        else
            echo "   Status: Stopped ❌"
        fi
    else
        echo "   Docker: Not installed"
    fi
    echo
    
    echo "🌐 Caddy Status:"
    if command -v caddy &> /dev/null; then
        caddy version
        if systemctl is-active --quiet caddy; then
            echo "   Status: Running ✅"
        else
            echo "   Status: Stopped ❌"
        fi
    else
        echo "   Caddy: Not installed"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to view log file
view_log_file() {
    print_header "📄 LOG FILE VIEWER"
    
    if [[ -f "$LOG_FILE" ]]; then
        print_info "Showing last 20 log entries:"
        echo
        tail -20 "$LOG_FILE"
    else
        print_warning "No log file found at $LOG_FILE"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Main function
main() {
    # Initialize
    check_root
    detect_os
    check_internet
    update_packages
    
    # Create log file
    touch "$LOG_FILE"
    log_action "VPS System Tools script started by $(whoami)"
    
    # Main menu loop
    while true; do
        # Use the improved menu display
        show_main_menu  # Or use show_main_menu_large for even bigger display
        
        read -p "$(print_color $YELLOW "        Choose an option [1-7]: ")" choice
        
        case $choice in
            1)
                set_timezone
                ;;
            2)
                setup_swap
                ;;
            3)
                install_docker
                ;;
            4)
                install_caddy
                ;;
            5)
                show_system_info
                ;;
            6)
                view_log_file
                ;;
            7)
                print_success "Thank you for using VPS System Tools! 🚀"
                log_action "VPS System Tools script ended"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please choose 1-7."
                sleep 2
                ;;
        esac
    done
}

# Check if script is being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

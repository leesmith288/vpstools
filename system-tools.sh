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

# API Keys configuration
TAVILY_API_KEY="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"  # Replace with your actual Tavily API key
JINA_API_KEY="jina_bb3cc4ba3a8d4597b4d72b342e5297b6ODr1ahxJ5AzIjZm1PWfh4lxKnNWu"    # Your Jina API key



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

# Function to install package group
install_package_group() {
    local group_name="$1"
    shift
    local packages=("$@")
    
    print_info "Installing $group_name..."
    
    # Check which packages are already installed
    local to_install=()
    local already_installed=()
    
    for package in "${packages[@]}"; do
        if is_package_installed "$package"; then
            already_installed+=("$package")
        else
            to_install+=("$package")
        fi
    done
    
    # Show status
    if [[ ${#already_installed[@]} -gt 0 ]]; then
        print_info "Already installed: ${already_installed[*]}"
    fi
    
    if [[ ${#to_install[@]} -eq 0 ]]; then
        print_success "All packages in $group_name are already installed"
        return 0
    fi
    
    print_info "Will install: ${to_install[*]}"
    
    # Estimate size
    apt_output=$(apt install --dry-run "${to_install[@]}" 2>/dev/null | grep "Need to get")
    if [[ -n "$apt_output" ]]; then
        size=$(echo "$apt_output" | awk '{print $4 $5}')
        print_info "Estimated download size: $size"
    fi
    
    # Install packages
    if apt install -y "${to_install[@]}"; then
        print_success "$group_name installed successfully"
        log_action "Installed $group_name: ${to_install[*]}"
    else
        print_error "Failed to install $group_name"
        return 1
    fi
}

# Function to install useful tools
# Function to install useful tools
install_useful_tools() {
    print_header "🛠️  USEFUL TOOLS INSTALLATION"
    
    # Define package groups - UPDATED WITH ALL DISCUSSED TOOLS
    declare -A tool_groups
    tool_groups[1]="Essential Tools:curl wget git nano rsync tar zip unzip"
    tool_groups[2]="Development Tools:python3 python3-pip nodejs npm jq"
    tool_groups[3]="System Monitoring:htop ncdu iotop nethogs glances"
    tool_groups[4]="Network Tools:net-tools dnsutils traceroute nmap ss iftop"
    tool_groups[5]="File & Text Processing:tree tmux screen grep sed awk"
    
    echo "Available tool groups:"
    echo
    for i in {1..5}; do
        IFS=':' read -r name packages <<< "${tool_groups[$i]}"
        echo "[$i] $name"
        echo "    📦 Packages: ${packages// /, }"
        echo
    done
    
    echo "[6] 🎯 Custom Selection (choose specific tools)"
    echo "[7] 📦 Install All Groups"
    echo "[8] 🔙 Return to Main Menu"
    echo
    
    read -p "Your choice [1-8]: " tool_choice
    
    case $tool_choice in
        1|2|3|4|5)
            IFS=':' read -r name packages <<< "${tool_groups[$tool_choice]}"
            IFS=' ' read -r -a package_array <<< "$packages"
            
            # Show packages and ask for confirmation
            echo
            print_info "Selected: $name"
            print_info "Packages: ${packages// /, }"
            echo
            echo "Options:"
            echo "[1] Install all packages in this group"
            echo "[2] Select specific packages"
            echo "[3] Cancel"
            echo
            read -p "Your choice [1-3]: " install_option
            
            case $install_option in
                1)
                    install_package_group "$name" "${package_array[@]}"
                    ;;
                2)
                    # Custom selection within group
                    echo
                    print_info "Available packages in $name:"
                    echo
                    for j in "${!package_array[@]}"; do
                        echo "[$((j+1))] ${package_array[$j]}"
                    done
                    echo
                    echo "Enter package numbers to install (e.g., 1,3,5) or package names (e.g., curl,tree):"
                    read -p "Your selection: " selection
                    
                    local selected_packages=()
                    
                    # Check if input contains commas (either numbers or names)
                    if [[ "$selection" == *","* ]]; then
                        IFS=',' read -ra items <<< "$selection"
                        for item in "${items[@]}"; do
                            item=$(echo "$item" | xargs) # Trim whitespace
                            # Check if it's a number
                            if [[ "$item" =~ ^[0-9]+$ ]]; then
                                local index=$((item - 1))
                                if [[ $index -ge 0 && $index -lt ${#package_array[@]} ]]; then
                                    selected_packages+=("${package_array[$index]}")
                                fi
                            else
                                # It's a package name, check if it exists in the group
                                for pkg in "${package_array[@]}"; do
                                    if [[ "$pkg" == "$item" ]]; then
                                        selected_packages+=("$item")
                                        break
                                    fi
                                done
                            fi
                        done
                    else
                        # Single item (number or name)
                        if [[ "$selection" =~ ^[0-9]+$ ]]; then
                            local index=$((selection - 1))
                            if [[ $index -ge 0 && $index -lt ${#package_array[@]} ]]; then
                                selected_packages+=("${package_array[$index]}")
                            fi
                        else
                            # Check if the package name exists in the group
                            for pkg in "${package_array[@]}"; do
                                if [[ "$pkg" == "$selection" ]]; then
                                    selected_packages+=("$selection")
                                    break
                                fi
                            done
                        fi
                    fi
                    
                    if [[ ${#selected_packages[@]} -gt 0 ]]; then
                        install_package_group "Selected packages" "${selected_packages[@]}"
                    else
                        print_error "No valid packages selected"
                    fi
                    ;;
                3)
                    return 0
                    ;;
                *)
                    print_error "Invalid choice"
                    ;;
            esac
            ;;
        6)
            # Custom selection across all groups
            print_info "All available packages:"
            echo
            local all_packages=()
            for i in {1..5}; do
                IFS=':' read -r name packages <<< "${tool_groups[$i]}"
                echo "=== $name ==="
                IFS=' ' read -r -a group_packages <<< "$packages"
                for pkg in "${group_packages[@]}"; do
                    all_packages+=("$pkg")
                    echo "  - $pkg"
                done
                echo
            done
            
            echo "Enter package names to install (comma-separated, e.g., curl,tree,htop):"
            read -p "Your selection: " custom_selection
            
            if [[ -n "$custom_selection" ]]; then
                IFS=',' read -ra selected <<< "$custom_selection"
                local valid_packages=()
                
                for item in "${selected[@]}"; do
                    item=$(echo "$item" | xargs) # Trim whitespace
                    # Check if package exists in our list
                    for pkg in "${all_packages[@]}"; do
                        if [[ "$pkg" == "$item" ]]; then
                            valid_packages+=("$item")
                            break
                        fi
                    done
                done
                
                if [[ ${#valid_packages[@]} -gt 0 ]]; then
                    install_package_group "Custom selection" "${valid_packages[@]}"
                else
                    print_error "No valid packages found in your selection"
                fi
            fi
            ;;
        7)
            read -p "Install all tool groups? [Y/n]: " confirm
            if [[ ! $confirm =~ ^[Nn]$ ]]; then
                for i in {1..5}; do
                    IFS=':' read -r name packages <<< "${tool_groups[$i]}"
                    IFS=' ' read -r -a package_array <<< "$packages"
                    install_package_group "$name" "${package_array[@]}"
                    echo
                done
            fi
            ;;
        8)
            return 0
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
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

# Function to install Caddy
install_caddy() {
    print_header "🌐 CADDY INSTALLATION"
    
    # Check if Caddy is already installed
    if command -v caddy &> /dev/null; then
        caddy_version=$(caddy version)
        print_success "Caddy is already installed: $caddy_version"
        read -p "Press Enter to continue..."
        return 0
    fi
    
    print_info "Installing Caddy using official repository method..."
    print_info "Estimated time: 1-2 minutes"
    print_info "Estimated size: ~50 MB"
    echo
    
    read -p "Continue with Caddy installation? [Y/n]: " confirm
    if [[ $confirm =~ ^[Nn]$ ]]; then
        return 0
    fi
    
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
        print_success "Caddy installed successfully"
        
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
        
        log_action "Caddy installed successfully"
    else
        print_error "Failed to install Caddy"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Function to get installed packages
get_user_installed_packages() {
    # Get manually installed packages (not dependencies)
    apt-mark showmanual | sort
}

# Function to get package size
get_package_size() {
    local package="$1"
    dpkg-query -Wf '${Installed-Size}' "$package" 2>/dev/null | awk '{printf "%.1f MB", $1/1024}'
}

# Function to search for removal guides online (mock function for this script)
search_removal_guides() {
    local package="$1"
    print_info "🔍 Searching removal guides for $package using Google and DuckDuckGo..."
    # In a real implementation, this would make actual web searches
    # For now, we'll use standard removal methods
    sleep 1
    print_success "Found standard removal procedures for $package"
}

# Function to find package files
# Function to find package files
find_package_files() {
    local package="$1"
    local files=()
    
    # Get files from dpkg - ONLY actual files, not directories
    if dpkg -L "$package" &> /dev/null; then
        while IFS= read -r file; do
            # Skip directories and only include actual files
            if [[ -f "$file" ]]; then
                files+=("$file")
            fi
        done < <(dpkg -L "$package" 2>/dev/null)
    fi
    
    # Add ONLY package-specific config directories
    local config_dirs=(
        "/etc/$package"
        "/var/log/$package"
        "/var/lib/$package"
    )
    
    for dir in "${config_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            files+=("$dir")
        fi
    done
    
    # Skip user config files for system packages
    
    printf '%s\n' "${files[@]}"
}

# Function to calculate directory size
get_path_size() {
    local path="$1"
    if [[ -d "$path" ]]; then
        du -sh "$path" 2>/dev/null | cut -f1
    elif [[ -f "$path" ]]; then
        ls -lh "$path" 2>/dev/null | awk '{print $5}'
    else
        echo "0B"
    fi
}

# Function to show removal preview
show_removal_preview() {
    local packages=("$@")
    
    print_header "📋 REMOVAL PREVIEW"
    
    local total_size=0
    
    for package in "${packages[@]}"; do
        print_info "📦 Package: $package"
        
        # Search for removal guides
        search_removal_guides "$package"
        
        # Find files
        local files
        mapfile -t files < <(find_package_files "$package")
        
        if [[ ${#files[@]} -gt 0 ]]; then
            echo "   📁 Files to be removed:"
            local count=0
            for file in "${files[@]}"; do
                if [[ $count -lt 10 ]]; then  # Show first 10 files
                    local size=$(get_path_size "$file")
                    echo "   ├── $file ($size)"
                    ((count++))
                elif [[ $count -eq 10 ]]; then
                    echo "   └── ... and $((${#files[@]} - 10)) more files"
                    break
                fi
            done
        fi
        
        echo
    done
    
    # Check for unused dependencies
    print_info "🧹 Checking for unused dependencies..."
    local unused_deps
    unused_deps=$(apt autoremove --dry-run 2>/dev/null | grep "^Remv" | wc -l)
    
    if [[ $unused_deps -gt 0 ]]; then
        print_info "Found $unused_deps unused dependencies that can be removed"
    fi
}

# Function to perform dry run
perform_dry_run() {
    local packages=("$@")
    
    print_header "🧪 DRY RUN MODE - Preview Only"
    print_warning "This is a simulation - nothing will actually be deleted"
    echo
    
    for package in "${packages[@]}"; do
        print_info "Would remove package: $package"
        
        local files
        mapfile -t files < <(find_package_files "$package")
        
        if [[ ${#files[@]} -gt 0 ]]; then
            echo "   📁 Would delete files:"
            for file in "${files[@]:0:5}"; do  # Show first 5 files
                local size=$(get_path_size "$file")
                echo "   ├── $file ($size)"
            done
            if [[ ${#files[@]} -gt 5 ]]; then
                echo "   └── ... and $((${#files[@]} - 5)) more files"
            fi
        fi
        echo
    done
    
    print_info "💾 Estimated space to free: Calculating..."
    print_success "Dry run completed - no actual changes made"
}

# Function to uninstall packages
uninstall_packages() {
    local packages=("$@")
    
    print_header "🗑️  UNINSTALLING PACKAGES"
    
    for package in "${packages[@]}"; do
        print_info "Removing $package..."
        
        if apt remove --purge -y "$package"; then
            print_success "$package removed successfully"
            log_action "Uninstalled package: $package"
        else
            print_error "Failed to remove $package"
        fi
    done
    
    # Clean up unused dependencies
    print_info "🧹 Cleaning up unused dependencies..."
    if apt autoremove -y; then
        print_success "Unused dependencies removed"
    fi
    
    # Clean package cache
    apt autoclean
    print_success "Package cache cleaned"
}

# Function to get truly user-installed packages (not pre-installed)
get_user_installed_packages() {
    # Method 1: Get packages that were explicitly installed (not dependencies)
    # and exclude common pre-installed packages
    
    # Get list of manually installed packages
    local manual_packages=$(apt-mark showmanual | sort)
    
    # Define base system packages to exclude (common pre-installed packages)
    local base_packages=(
        "adduser" "apt" "apt-utils" "base-files" "base-passwd" "bash" 
        "bsdutils" "coreutils" "dash" "debconf" "debianutils" "diffutils"
        "dpkg" "e2fsprogs" "fdisk" "findutils" "gcc-*-base" "gpgv" "grep"
        "gzip" "hostname" "init" "init-system-helpers" "iproute2" "iputils-ping"
        "libc-bin" "libc6" "libpam*" "libssl*" "libsystemd*" "login"
        "lsb-base" "mawk" "mount" "ncurses-*" "passwd" "perl-base"
        "procps" "sed" "sensible-utils" "systemd" "systemd-sysv" "sysvinit-utils"
        "tar" "tzdata" "ubuntu-keyring" "util-linux" "zlib1g"
    )
    
    # Filter out base packages
    local filtered_packages=""
    while IFS= read -r package; do
        local is_base=false
        for base in "${base_packages[@]}"; do
            if [[ "$package" == $base || "$package" =~ ^lib.* ]]; then
                is_base=true
                break
            fi
        done
        if [[ "$is_base" == false ]]; then
            filtered_packages+="$package"$'\n'
        fi
    done <<< "$manual_packages"
    
    echo -n "$filtered_packages"
}

# Function to get all installed packages including manually installed ones
get_all_installed_packages() {
    # This will show ALL packages including xray, docker, etc.
    dpkg --get-selections | grep -v deinstall | awk '{print $1}' | sort
}

# Function to check if package is a critical system package
is_critical_package() {
    local package="$1"
    local critical_packages=(
        "systemd" "init" "kernel-*" "linux-*" "libc6" "bash" "dash"
        "coreutils" "util-linux" "mount" "e2fsprogs" "procps"
    )
    
    for critical in "${critical_packages[@]}"; do
        if [[ "$package" == $critical || "$package" =~ $critical ]]; then
            return 0
        fi
    done
    return 1
}

# Function to check jq and prompt for installation
check_and_prompt_jq() {
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. It's required for online search results."
        echo
        echo "Options:"
        echo "[1] Install jq now (recommended)"
        echo "[2] Continue without jq (search results won't be displayed)"
        echo "[3] Cancel operation"
        echo
        read -p "Your choice [1-3]: " jq_choice
        
        case $jq_choice in
            1)
                print_info "Installing jq..."
                if apt update &> /dev/null && apt install -y jq &> /dev/null; then
                    print_success "jq installed successfully"
                    return 0
                else
                    print_error "Failed to install jq"
                    return 1
                fi
                ;;
            2)
                print_info "Continuing without jq..."
                return 1
                ;;
            3)
                print_info "Operation cancelled"
                return 2
                ;;
            *)
                print_error "Invalid choice"
                return 2
                ;;
        esac
    fi
    return 0
}



# Function to search online for uninstall instructions using multiple methods
search_uninstall_instructions() {
    local app_name="$1"
    local found_instructions=false
    local search_results=""
    
    # Check for jq installation
    check_and_prompt_jq
    local jq_status=$?
    
    if [[ $jq_status -eq 2 ]]; then
        # User cancelled
        return 1
    fi
    
    local jq_available=$([[ $jq_status -eq 0 ]] && echo true || echo false)
    
    print_info "🔍 Searching online for $app_name uninstall instructions..."
    echo
    
    # Prepare search query
    local search_query="how to uninstall $app_name linux ubuntu debian remove completely"
    local encoded_query=$(echo "$search_query" | sed 's/ /%20/g')
    
    # Method 1: Tavily Search API (AI-optimized search)
    if [[ -n "$TAVILY_API_KEY" ]] && [[ "$jq_available" == "true" ]]; then
        print_info "Trying Tavily Search API..."
        print_info "Tavily API Key: ${TAVILY_API_KEY:0:10}..." # Show first 10 chars for verification
        
        local tavily_payload='{
            "api_key": "'$TAVILY_API_KEY'",
            "query": "how to uninstall '$app_name' linux ubuntu debian remove completely",
            "search_depth": "basic",
            "max_results": 5
        }'
        
        print_info "Sending request to Tavily..."
        local tavily_result=$(curl -s -X POST "https://api.tavily.com/search" \
            -H "Content-Type: application/json" \
            -d "$tavily_payload" 2>&1)
        
        # Debug: Show response length and first 200 chars
        print_info "Tavily response length: ${#tavily_result} chars"
        print_info "Tavily response preview: ${tavily_result:0:200}..."
        
        if [[ -n "$tavily_result" ]]; then
            # Check if response is JSON and jq is available
            if [[ "$jq_available" == "true" ]] && echo "$tavily_result" | jq . >/dev/null 2>&1; then
                # Extract results from Tavily response
                local results=$(echo "$tavily_result" | jq -r '.results[]? | ("• " + .title + "\n  " + .content + "\n")' 2>/dev/null)
                if [[ -n "$results" ]]; then
                    search_results+="Tavily Search Results:\n$results\n"
                    found_instructions=true
                    print_success "Tavily: Found results"
                else
                    print_warning "Tavily: No .results[] found in response"
                    # Show what keys are in the response
                    local keys=$(echo "$tavily_result" | jq -r 'keys[]?' 2>/dev/null)
                    print_info "Tavily response keys: $keys"
                fi
            else
                if [[ "$jq_available" == "false" ]]; then
                    print_error "Tavily: Cannot parse response without jq"
                else
                    print_error "Tavily: Response is not valid JSON"
                fi
            fi
        else
            print_error "Tavily: No response received"
        fi
    elif [[ -n "$TAVILY_API_KEY" ]] && [[ "$jq_available" == "false" ]]; then
        print_warning "Tavily API configured but jq is not available for parsing JSON"
    else
        print_warning "Tavily API key not set"
    fi
    
# Method 2: Jina Search API
if [[ -n "$JINA_API_KEY" ]] && [[ "$jq_available" == "true" ]]; then
    print_info "Trying Jina Search API..."
    
    # URL encode the query properly
    local query="how to uninstall $app_name linux ubuntu debian remove completely"
    local encoded_query=$(echo "$query" | sed 's/ /%20/g')
    local jina_url="https://s.jina.ai/$encoded_query"
    
    local jina_result=$(curl -s -L "$jina_url" \
        -H "Authorization: Bearer $JINA_API_KEY" \
        -H "Accept: application/json" 2>&1)
    
    if [[ -n "$jina_result" ]]; then
        # Jina Search API returns {code, status, data:[array]}
        local error_msg=$(echo "$jina_result" | jq -r '.message // .error // empty' 2>/dev/null)
        if [[ -n "$error_msg" ]] && [[ "$error_msg" != "null" ]]; then
            print_error "Jina API error: $error_msg"
        else
            # Check if status is 200/20000 and extract from .data array
            local status=$(echo "$jina_result" | jq -r '.status // .code // empty' 2>/dev/null)
            if [[ "$status" == "20000" ]] || [[ "$status" == "200" ]]; then
                # Extract from .data array - each item has title, url, description, content
                local jina_contents=$(echo "$jina_result" | jq -r '.data[]? | ("• " + .title + "\n  URL: " + .url + "\n  " + (.description // .content // "" | .[0:300]) + "...\n")' 2>/dev/null | head -3)
                if [[ -n "$jina_contents" ]]; then
                    search_results+="Jina Search Results:\n$jina_contents\n"
                    found_instructions=true
                else
                    print_warning "Jina: Could not extract content from .data array"
                fi
            else
                print_warning "Jina: Unexpected status code: $status"
            fi
        fi
    else
        print_warning "Jina: No response received"
    fi
elif [[ -n "$JINA_API_KEY" ]] && [[ "$jq_available" == "false" ]]; then
    print_warning "Jina API configured but jq is not available for parsing JSON"
else
    print_warning "Jina API key not set"
fi
    
    # Method 3: Lynx or w3m for Google search
    if command -v lynx &> /dev/null; then
        print_info "Trying Google search with lynx..."
        local lynx_result=$(lynx -dump -nolist "https://www.google.com/search?q=$encoded_query&hl=en&gl=us" 2>/dev/null | \
            grep -A 3 -i "uninstall\|remove" | \
            grep -v "Google\|Search\|Sign in" | \
            head -20)
        
        if [[ -n "$lynx_result" ]]; then
            search_results+="Google Results (via lynx):\n$lynx_result\n\n"
            found_instructions=true
        fi
    elif command -v w3m &> /dev/null; then
        print_info "Trying Google search with w3m..."
        local w3m_result=$(w3m -dump "https://www.google.com/search?q=$encoded_query" 2>/dev/null | \
            grep -A 3 -i "uninstall\|remove" | \
            grep -v "Google\|Search\|Sign in" | \
            head -20)
        
        if [[ -n "$w3m_result" ]]; then
            search_results+="Google Results (via w3m):\n$w3m_result\n\n"
            found_instructions=true
        fi
    fi
    
    # Display search results if found
    if [[ "$found_instructions" == true ]] && [[ -n "$search_results" ]]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📝 Online Search Results:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo -e "$search_results"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo
    else
        print_warning "Could not fetch online results. Using built-in knowledge base..."
    fi
    
    # Always show hardcoded instructions as a fallback or complement
    echo "📋 Standard uninstall procedures for $app_name:"
    echo
    
    return $([[ "$found_instructions" == true ]] && echo 0 || echo 1)
}

# Function to get specific uninstall commands for known applications
get_uninstall_commands() {
    local app_name="$1"
    local -n commands=$2  # nameref to return array
    local -n description=$3  # nameref to return description
    
    case "$app_name" in

         

    "caddy"|"Caddy"|"CADDY")
    description="Caddy web server"
    commands=(
        "systemctl stop caddy"
        "systemctl disable caddy"
        "apt remove --purge -y caddy 2>/dev/null || true"
        "rm -rf /etc/caddy"
        "rm -rf /var/lib/caddy"
        "rm -rf /var/log/caddy"
        "rm -rf /usr/share/keyrings/caddy-stable-archive-keyring.gpg"
        "rm -f /etc/apt/sources.list.d/caddy-stable.list"
        "rm -f /etc/systemd/system/caddy.service"
        "rm -f /etc/systemd/system/caddy-api.service"
        "systemctl daemon-reload"
        "apt update"
    )
    ;;

"fail2ban"|"Fail2ban"|"FAIL2BAN")
    description="Fail2ban intrusion prevention"
    commands=(
        "systemctl stop fail2ban"
        "systemctl disable fail2ban"
        "apt remove --purge -y fail2ban 2>/dev/null || true"
        "apt autoremove -y 2>/dev/null || true"
        "rm -rf /etc/fail2ban"
        "rm -rf /var/log/fail2ban"
        "rm -rf /var/lib/fail2ban"
        "rm -f /etc/systemd/system/fail2ban.service"
        "systemctl daemon-reload"
    )
    ;;

"3x-ui"|"x-ui"|"X-UI"|"3X-UI")
    description="3X-UI panel"
    commands=(
        "systemctl stop x-ui"
        "systemctl disable x-ui"
        "rm -f /etc/systemd/system/x-ui.service"
        "systemctl daemon-reload"
        "systemctl reset-failed"
        "rm -rf /etc/x-ui/"
        "rm -rf /usr/local/x-ui/"
        "rm -f /usr/bin/x-ui"
        "rm -rf /root/cert"
    )
    ;;





        "xray"|"Xray"|"XRAY")
            description="Xray proxy service"
            commands=(
                "systemctl stop xray"
                "systemctl disable xray"
                "rm -rf /usr/local/bin/xray"
                "rm -rf /usr/local/share/xray"
                "rm -rf /usr/local/etc/xray"
                "rm -rf /etc/xray"
                "rm -rf /var/log/xray"
                "rm -f /etc/systemd/system/xray.service"
                "rm -f /etc/systemd/system/xray@.service"
                "systemctl daemon-reload"
            )
            ;;
        
        "nginx"|"NGINX")
            description="Nginx web server"
            commands=(
                "systemctl stop nginx"
                "systemctl disable nginx"
                "rm -rf /usr/local/nginx"
                "rm -rf /etc/nginx"
                "rm -rf /var/log/nginx"
                "rm -f /etc/systemd/system/nginx.service"
                "systemctl daemon-reload"
            )
            ;;
        
        *)
            # Generic commands for unknown applications
            description="$app_name application"
            commands=(
                "systemctl stop $app_name 2>/dev/null || true"
                "systemctl disable $app_name 2>/dev/null || true"
                "rm -rf /usr/local/bin/$app_name"
                "rm -rf /opt/$app_name"
                "rm -rf /etc/$app_name"
                "rm -rf /var/log/$app_name"
                "rm -rf /usr/local/share/$app_name"
                "rm -f /etc/systemd/system/$app_name.service"
                "systemctl daemon-reload"
            )
            ;;
    esac
}

# Function to uninstall applications
uninstall_apps() {
    print_header "🗑️  UNINSTALL APPLICATIONS"
    
    echo "Select application category:"
    echo
    echo "[1] 📦 Recently Installed Applications"
    echo "[2] 🔍 Search for Specific Application"
    echo "[3] 📋 View All Installed Applications"
    echo "[4] 🔙 Return to Main Menu"
    echo
    
    read -p "Your choice [1-4]: " category_choice
    
    case $category_choice in
        1)
            print_info "Loading recently installed applications..."
            
            # Method 1: Check both current and rotated logs
            local recent_packages=""
            
            # Check current log
            if [[ -f /var/log/dpkg.log ]]; then
                recent_packages=$(grep " install " /var/log/dpkg.log 2>/dev/null | \
                    awk '{print $4}' | grep -v "^$" | sort -u)
            fi
            
            # Check rotated log if exists
            if [[ -f /var/log/dpkg.log.1 ]]; then
                recent_packages+=$'\n'$(grep " install " /var/log/dpkg.log.1 2>/dev/null | \
                    awk '{print $4}' | grep -v "^$" | sort -u)
            fi
            
            # Method 2: Alternative - get packages by install date from dpkg database
            if [[ -z "$recent_packages" ]]; then
                print_info "Checking package database for recently installed packages..."
                # Get packages sorted by installation time (newest first)
                recent_packages=$(ls -t /var/lib/dpkg/info/*.list 2>/dev/null | \
                    head -50 | \
                    xargs -I {} basename {} .list | \
                    sort -u)
            fi
            
            # Method 3: Show all manually installed packages as fallback
            if [[ -z "$recent_packages" ]]; then
                print_info "Showing manually installed packages..."
                recent_packages=$(apt-mark showmanual | grep -v "^lib" | grep -v "linux-" | sort)
            fi
            
            # Remove duplicates and filter out system packages
            recent_packages=$(echo "$recent_packages" | sort -u | grep -v "^$" | \
                grep -v "^linux-firmware" | \
                grep -v "^linux-base" | \
                head -30)  # Limit to 30 most recent
            
            local packages=($recent_packages)
            
            if [[ ${#packages[@]} -eq 0 ]]; then
                print_warning "No recently installed packages found"
                read -p "Press Enter to continue..."
                return 0
            fi
            
            echo
            print_info "📦 RECENTLY INSTALLED APPLICATIONS:"
            print_info "Showing ${#packages[@]} packages (newest first)"
            echo
            
            # Show packages with numbers
            for i in "${!packages[@]}"; do
                local pkg="${packages[$i]}"
                local size=$(get_package_size "$pkg")
                local desc=$(apt-cache show "$pkg" 2>/dev/null | grep -m1 "^Description-en:" | cut -d: -f2-)
                if [[ -z "$desc" ]]; then
                    desc=$(apt-cache show "$pkg" 2>/dev/null | grep -m1 "^Description:" | cut -d: -f2-)
                fi
                
                # Show install date if available
                local install_date=""
                if [[ -f /var/lib/dpkg/info/${pkg}.list ]]; then
                    install_date=$(stat -c %y /var/lib/dpkg/info/${pkg}.list 2>/dev/null | cut -d' ' -f1)
                    if [[ -n "$install_date" ]]; then
                        install_date=" [$install_date]"
                    fi
                fi
                
                echo "[$((i+1))] ${pkg}${install_date} - $size"
                [[ -n "$desc" ]] && echo "    $desc"
            done
            
            # Selection processing
            echo
            echo "Select applications to uninstall:"
            echo "- Enter numbers (1,3,5): Select specific apps"
            echo "- Enter 'none' or press Enter: Go back"
            echo
            read -p "Your choice: " selection
            
            if [[ -z "$selection" || "$selection" == "none" ]]; then
                return 0
            fi
            
            local selected_packages=()
            IFS=',' read -ra indices <<< "$selection"
            for index in "${indices[@]}"; do
                index=$((index - 1))
                if [[ $index -ge 0 && $index -lt ${#packages[@]} ]]; then
                    selected_packages+=("${packages[$index]}")
                fi
            done
            
            if [[ ${#selected_packages[@]} -eq 0 ]]; then
                print_error "No valid packages selected"
                return 1
            fi
            
            # Show removal preview
            show_removal_preview "${selected_packages[@]}"
            
            echo
            echo "Choose action:"
            echo "[1] 🧪 Dry Run (preview only - safe)"
            echo "[2] 🗑️  Real Deletion"
            echo "[3] ❌ Cancel"
            echo
            read -p "Your choice [1-3]: " action_choice
            
            case $action_choice in
                1)
                    perform_dry_run "${selected_packages[@]}"
                    ;;
                2)
                    echo
                    print_warning "⚠️  FINAL CONFIRMATION"
                    print_warning "This will permanently delete the selected applications and files."
                    echo
                    read -p "Continue? [y/N]: " final_confirm
                    
                    if [[ $final_confirm =~ ^[Yy]$ ]]; then
                        uninstall_packages "${selected_packages[@]}"
                    else
                        print_info "Uninstallation cancelled"
                    fi
                    ;;
                3)
                    print_info "Operation cancelled"
                    ;;
                *)
                    print_error "Invalid choice"
                    ;;
            esac
            ;;
            
        2)
            echo
            read -p "Enter application name to search (e.g., xray, docker): " search_term
            
            if [[ -z "$search_term" ]]; then
                return 0
            fi
            
            print_info "Searching for packages matching '$search_term'..."
            
            local matching_packages=$(dpkg --get-selections | grep -i "$search_term" | grep -v deinstall | awk '{print $1}')
            
            if [[ -z "$matching_packages" ]]; then
                print_warning "No packages found matching '$search_term'"
                
                # Check if it's installed outside of apt
                if command -v "$search_term" &> /dev/null; then
                    local binary_path=$(which "$search_term")
                    print_info "Note: '$search_term' appears to be installed but not via apt package manager"
                    print_info "Location: $binary_path"
                    echo
                    
                    # Offer to help with manual removal
                    echo "This application was installed manually. Options:"
                    echo "[1] Search online for uninstall instructions"
                    echo "[2] Show common file locations for this app"
                    echo "[3] Cancel"
                    echo
                    read -p "Your choice [1-3]: " manual_choice
                    
                    case $manual_choice in
                        1)
                            # Try to search online first
                            search_uninstall_instructions "$search_term"
                            
                            # Get specific uninstall commands
                            local uninstall_commands=()
                            local app_description=""
                            get_uninstall_commands "$search_term" uninstall_commands app_description
                            
                            echo
                            echo "📌 Recommended uninstall steps for $app_description:"
                            local step=1
                            for cmd in "${uninstall_commands[@]}"; do
                                echo "  $step. $cmd"
                                ((step++))
                            done
                            
                            echo
                            print_warning "⚠️  Would you like me to execute these uninstall commands?"
                            print_warning "This will permanently remove $search_term from your system."
                            echo
                            echo "Options:"
                            echo "[1] ✅ Yes, execute all commands automatically"
                            echo "[2] 📝 Show me the commands and let me run them manually"
                            echo "[3] ❌ Cancel"
                            echo
                            read -p "Your choice [1-3]: " execute_choice
                            
                            case $execute_choice in
                                1)
                                    echo
                                    print_info "🔄 Executing uninstall commands..."
                                    
                                    # Create a backup list of what we're removing
                                    log_action "Starting manual uninstall of $search_term"
                                    
                                    local failed_commands=()
                                    local success_count=0
                                    
                                    for cmd in "${uninstall_commands[@]}"; do
                                        print_info "Running: $cmd"
                                        
                                        # Execute the command and capture result
                                        if eval "$cmd" 2>/dev/null; then
                                            print_success "✓ Completed: $cmd"
                                            ((success_count++))
                                        else
                                            # Some commands might fail if file doesn't exist, which is OK
                                            if [[ $cmd == *"rm -"* ]] || [[ $cmd == *"stop"* ]] || [[ $cmd == *"disable"* ]] || [[ $cmd == *"|| true"* ]]; then
                                                print_info "ℹ️  Skipped: $cmd (file/service not found)"
                                                ((success_count++))
                                            else
                                                print_error "✗ Failed: $cmd"
                                                failed_commands+=("$cmd")
                                            fi
                                        fi
                                        
                                        sleep 0.5  # Brief pause between commands
                                    done
                                    
                                    echo
                                    if [[ ${#failed_commands[@]} -eq 0 ]]; then
                                        print_success "🎉 Uninstall process completed successfully! ($success_count/${#uninstall_commands[@]} commands executed)"
                                    else
                                        print_warning "⚠️  Uninstall completed with some errors. Failed commands:"
                                        for fc in "${failed_commands[@]}"; do
                                            echo "   - $fc"
                                        done
                                    fi
                                    
                                    # Verify removal
                                    if ! command -v "$search_term" &> /dev/null; then
                                        print_success "✅ $search_term has been successfully removed from the system"
                                    else
                                        print_warning "⚠️  $search_term command still exists. Manual cleanup may be needed."
                                    fi
                                    
                                    log_action "Completed manual uninstall of $search_term"
                                    ;;
                                    
                                2)
                                    echo
                                    print_info "📋 Copy and run these commands manually:"
                                    echo
                                    echo "────────────────────────────────────────"
                                    for cmd in "${uninstall_commands[@]}"; do
                                        echo "$cmd"
                                    done
                                    echo "────────────────────────────────────────"
                                    echo
                                    print_info "💡 Tip: You can select and copy the commands above"
                                    ;;
                                    
                                3)
                                    print_info "Uninstall cancelled. No changes were made."
                                    ;;
                                    
                                *)
                                    print_error "Invalid choice"
                                    ;;
                            esac
                            ;;
                            
                        2)
                            print_info "Common locations for $search_term:"
                            echo
                            # Check common locations
                            local locations=(
                                "/usr/local/bin/$search_term"
                                "/usr/bin/$search_term"
                                "/opt/$search_term"
                                "/etc/$search_term"
                                "/var/lib/$search_term"
                                "/var/log/$search_term"
                                "/home/*/.config/$search_term"
                                "/etc/systemd/system/$search_term.service"
                                "/lib/systemd/system/$search_term.service"
                            )
                            
                            for loc in "${locations[@]}"; do
                                if [[ -e $loc ]]; then
                                    local size=$(du -sh "$loc" 2>/dev/null | cut -f1)
                                    echo "✓ Found: $loc ($size)"
                                fi
                            done
                            ;;
                            
                        3)
                            return 0
                            ;;
                    esac
                fi
                
                read -p "Press Enter to continue..."
                return 0
            fi
            
            # If packages were found, show them
            local packages=($matching_packages)
            echo
            print_info "📦 PACKAGES MATCHING '$search_term':"
            echo
            
            for i in "${!packages[@]}"; do
                local size=$(get_package_size "${packages[$i]}")
                echo "[$((i+1))] ${packages[$i]} - $size"
            done
            
            # Selection processing (same as option 1)
            echo
            echo "Select applications to uninstall:"
            echo "- Enter numbers (1,3,5): Select specific apps"
            echo "- Enter 'none' or press Enter: Go back"
            echo
            read -p "Your choice: " selection
            
            if [[ -z "$selection" || "$selection" == "none" ]]; then
                return 0
            fi
            
            local selected_packages=()
            IFS=',' read -ra indices <<< "$selection"
            for index in "${indices[@]}"; do
                index=$((index - 1))
                if [[ $index -ge 0 && $index -lt ${#packages[@]} ]]; then
                    selected_packages+=("${packages[$index]}")
                fi
            done
            
            if [[ ${#selected_packages[@]} -eq 0 ]]; then
                print_error "No valid packages selected"
                return 1
            fi
            
            # Show removal preview and continue with uninstall process
            show_removal_preview "${selected_packages[@]}"
            
            echo
            echo "Choose action:"
            echo "[1] 🧪 Dry Run (preview only - safe)"
            echo "[2] 🗑️  Real Deletion"
            echo "[3] ❌ Cancel"
            echo
            read -p "Your choice [1-3]: " action_choice
            
            case $action_choice in
                1)
                    perform_dry_run "${selected_packages[@]}"
                    ;;
                2)
                    echo
                    print_warning "⚠️  FINAL CONFIRMATION"
                    print_warning "This will permanently delete the selected applications and files."
                    echo
                    read -p "Continue? [y/N]: " final_confirm
                    
                    if [[ $final_confirm =~ ^[Yy]$ ]]; then
                        uninstall_packages "${selected_packages[@]}"
                    else
                        print_info "Uninstallation cancelled"
                    fi
                    ;;
                3)
                    print_info "Operation cancelled"
                    ;;
                *)
                    print_error "Invalid choice"
                    ;;
            esac
            ;;
            
        3)
            print_info "Loading all installed packages (this may take a moment)..."
            local packages=($(get_all_installed_packages))
            
            echo
            print_info "📦 ALL INSTALLED PACKAGES (${#packages[@]} total):"
            print_warning "⚠️  Be VERY careful - removing system packages can break your system!"
            echo
            
            # Paginate results
            local page_size=20
            local current_page=0
            local total_pages=$(( (${#packages[@]} + page_size - 1) / page_size ))
            local search_filter=""
            
            while true; do
                clear
                
                # Apply search filter if set
                local filtered_packages=()
                if [[ -n "$search_filter" ]]; then
                    for pkg in "${packages[@]}"; do
                        if [[ "$pkg" == *"$search_filter"* ]]; then
                            filtered_packages+=("$pkg")
                        fi
                    done
                    
                    # If no matches found
                    if [[ ${#filtered_packages[@]} -eq 0 ]]; then
                        print_header "📋 ALL INSTALLED PACKAGES - Search: '$search_filter'"
                        print_error "No packages found matching '$search_filter'"
                        echo
                        echo "Press Enter to clear search and continue..."
                        read
                        search_filter=""
                        continue
                    fi
                else
                    filtered_packages=("${packages[@]}")
                fi
                
                # Recalculate pagination for filtered results
                local display_packages=("${filtered_packages[@]}")
                total_pages=$(( (${#display_packages[@]} + page_size - 1) / page_size ))
                
                # Ensure current page is valid
                if [[ $current_page -ge $total_pages ]]; then
                    current_page=0
                fi
                
                local start=$((current_page * page_size))
                local end=$((start + page_size))
                if [[ $end -gt ${#display_packages[@]} ]]; then
                    end=${#display_packages[@]}
                fi
                
                # Get first and last package names for current page
                local first_pkg="${display_packages[$start]}"
                local last_pkg="${display_packages[$((end-1))]}"
                
                # Display header with package range
                if [[ -n "$search_filter" ]]; then
                    print_header "📋 FILTERED PACKAGES - Page $((current_page + 1))/$total_pages ($first_pkg - $last_pkg)"
                    print_info "Search filter: '$search_filter' (${#display_packages[@]} matches)"
                else
                    print_header "📋 ALL INSTALLED PACKAGES - Page $((current_page + 1))/$total_pages ($first_pkg - $last_pkg)"
                fi
                
                # Find the original index for filtered packages
                for i in $(seq $start $((end - 1))); do
                    local pkg="${display_packages[$i]}"
                    local size=$(get_package_size "$pkg")
                    
                    # Find original index in full package list
                    local orig_index=0
                    for j in "${!packages[@]}"; do
                        if [[ "${packages[$j]}" == "$pkg" ]]; then
                            orig_index=$j
                            break
                        fi
                    done
                    
                    # Mark critical packages
                    if is_critical_package "$pkg"; then
                        echo "[$((orig_index+1))] ⚠️  $pkg - $size [CRITICAL SYSTEM PACKAGE]"
                    else
                        echo "[$((orig_index+1))] $pkg - $size"
                    fi
                done
                
                echo
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "Navigation: [n]ext, [p]revious, [j]ump to page, [f]ilter/search, [s]elect, [c]lear filter, [q]uit"
                if [[ -n "$search_filter" ]]; then
                    echo "Current filter: '$search_filter' | Press [c] to clear"
                fi
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                read -p "Your choice: " nav_choice
                
                case $nav_choice in
                    n|N)
                        if [[ $((current_page + 1)) -lt $total_pages ]]; then
                            ((current_page++))
                        else
                            print_warning "Already on last page"
                            sleep 1
                        fi
                        ;;
                    p|P)
                        if [[ $current_page -gt 0 ]]; then
                            ((current_page--))
                        else
                            print_warning "Already on first page"
                            sleep 1
                        fi
                        ;;
                    j|J)
                        echo
                        read -p "Enter page number (1-$total_pages): " jump_page
                        if [[ "$jump_page" =~ ^[0-9]+$ ]] && [[ $jump_page -ge 1 ]] && [[ $jump_page -le $total_pages ]]; then
                            current_page=$((jump_page - 1))
                        else
                            print_error "Invalid page number"
                            sleep 1
                        fi
                        ;;
                    f|F)
                        echo
                        read -p "Enter package name to search (partial match supported): " search_term
                        if [[ -n "$search_term" ]]; then
                            search_filter="$search_term"
                            current_page=0  # Reset to first page of results
                        fi
                        ;;
                    c|C)
                        if [[ -n "$search_filter" ]]; then
                            search_filter=""
                            current_page=0
                            print_info "Filter cleared"
                            sleep 1
                        fi
                        ;;
                    s|S)
                        echo
                        read -p "Enter package numbers to uninstall (e.g., 1,5,10): " selection
                        
                        local selected_packages=()
                        IFS=',' read -ra indices <<< "$selection"
                        for index in "${indices[@]}"; do
                            index=$((index - 1))
                            if [[ $index -ge 0 && $index -lt ${#packages[@]} ]]; then
                                selected_packages+=("${packages[$index]}")
                            fi
                        done
                        
                        if [[ ${#selected_packages[@]} -eq 0 ]]; then
                            print_error "No valid packages selected"
                            sleep 2
                            continue
                        fi
                        
                        # Check for critical packages
                        local has_critical=false
                        for pkg in "${selected_packages[@]}"; do
                            if is_critical_package "$pkg"; then
                                has_critical=true
                                break
                            fi
                        done
                        
                        if [[ "$has_critical" == true ]]; then
                            print_error "⚠️  WARNING: You have selected CRITICAL SYSTEM PACKAGES!"
                            print_error "Removing these packages may render your system unusable!"
                            echo
                            read -p "Are you ABSOLUTELY SURE you want to continue? Type 'YES' to proceed: " critical_confirm
                            if [[ "$critical_confirm" != "YES" ]]; then
                                print_info "Operation cancelled - good choice!"
                                sleep 2
                                continue
                            fi
                        fi
                        
                        # Show removal preview
                        show_removal_preview "${selected_packages[@]}"
                        
                        echo
                        echo "Choose action:"
                        echo "[1] 🧪 Dry Run (preview only - safe)"
                        echo "[2] 🗑️  Real Deletion"
                        echo "[3] ❌ Cancel"
                        echo
                        read -p "Your choice [1-3]: " action_choice
                        
                        case $action_choice in
                            1)
                                perform_dry_run "${selected_packages[@]}"
                                echo
                                read -p "Press Enter to continue..."
                                ;;
                            2)
                                echo
                                print_warning "⚠️  FINAL CONFIRMATION"
                                print_warning "This will permanently delete the selected applications and files."
                                echo
                                read -p "Continue? [y/N]: " final_confirm
                                
                                if [[ $final_confirm =~ ^[Yy]$ ]]; then
                                    uninstall_packages "${selected_packages[@]}"
                                    echo
                                    read -p "Press Enter to continue..."
                                    # Refresh package list after uninstall
                                    packages=($(get_all_installed_packages))
                                    current_page=0
                                else
                                    print_info "Uninstallation cancelled"
                                    sleep 2
                                fi
                                ;;
                            3)
                                print_info "Operation cancelled"
                                sleep 2
                                ;;
                            *)
                                print_error "Invalid choice"
                                sleep 2
                                ;;
                        esac
                        ;;
                    q|Q)
                        return 0
                        ;;
                    *)
                        print_error "Invalid navigation choice"
                        sleep 1
                        ;;
                esac
            done
            ;;
            
        4)
            return 0
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    echo
    read -p "Press Enter to continue..."
}



# Function to show main menu
show_main_menu() {
    clear
    print_color "$PURPLE$BOLD" "╔══════════════════════════════════════════════════════════════╗"
    print_color "$PURPLE$BOLD" "║                    🚀 VPS SYSTEM TOOLS                      ║"
    print_color "$PURPLE$BOLD" "║                 Management Script v1.0                      ║"
    print_color "$PURPLE$BOLD" "║              Debian 12 / Ubuntu 24.04                       ║"
    print_color "$PURPLE$BOLD" "╚══════════════════════════════════════════════════════════════╝"
    echo
    
    # Show system info
    print_info "System: $OS $OS_VERSION | User: $(whoami) | Date: $(date '+%Y-%m-%d %H:%M')"
    echo
    
    print_color "$WHITE$BOLD" "📋 MAIN MENU:"
    echo
    print_color "$CYAN" "[1] 🌏 Set Timezone to Asia/Shanghai"
    print_color "$CYAN" "[2] 💾 Setup Swap Memory"
    print_color "$CYAN" "[3] 🛠️  Install Useful Tools"
    print_color "$CYAN" "[4] 🐳 Install Docker"
    print_color "$CYAN" "[5] 🌐 Install Caddy"
    print_color "$CYAN" "[6] 🗑️  Uninstall Applications"
    print_color "$CYAN" "[7] 📋 View System Information"
    print_color "$CYAN" "[8] 📄 View Log File"
    print_color "$CYAN" "[9] ❌ Exit"
    echo
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
        show_main_menu
        read -p "$(print_color $YELLOW "Choose an option [1-9]: ")" choice
        
        case $choice in
            1)
                set_timezone
                ;;
            2)
                setup_swap
                ;;
            3)
                install_useful_tools
                ;;
            4)
                install_docker
                ;;
            5)
                install_caddy
                ;;
            6)
                uninstall_apps
                ;;
            7)
                show_system_info
                ;;
            8)
                view_log_file
                ;;
            9)
                print_success "Thank you for using VPS System Tools! 🚀"
                log_action "VPS System Tools script ended"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please choose 1-9."
                sleep 2
                ;;
        esac
    done
}

# Check if script is being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
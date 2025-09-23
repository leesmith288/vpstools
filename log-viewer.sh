#!/bin/bash

# VPS Log Viewer and System Monitor
# Author: System Tools Suite
# Description: Comprehensive log viewer and system monitor for Ubuntu/Debian VPS
# Features: Docker logs, system logs, application logs with advanced filtering

# ============================================================================
# COLOR DEFINITIONS - High Contrast for Myopia Users
# ============================================================================
RED='\033[1;91m'      # Bright Red for errors
GREEN='\033[1;92m'    # Bright Green for success
YELLOW='\033[1;93m'   # Bright Yellow for warnings
BLUE='\033[1;94m'     # Bright Blue for info
PURPLE='\033[1;95m'   # Bright Purple for headers
CYAN='\033[1;96m'     # Bright Cyan for highlights
WHITE='\033[1;97m'    # Bright White for text
ORANGE='\033[38;5;208m' # Orange for special highlights
NC='\033[0m'          # No Color
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'
BLINK='\033[5m'
REVERSE='\033[7m'

# Log severity colors
COLOR_ERROR="${RED}${BOLD}"
COLOR_WARNING="${YELLOW}${BOLD}"
COLOR_INFO="${CYAN}"
COLOR_DEBUG="${DIM}"
COLOR_CRITICAL="${RED}${REVERSE}"

# ============================================================================
# CONFIGURATION
# ============================================================================
SCRIPT_VERSION="2.0"
LOG_DIR="/var/log"
TEMP_DIR="/tmp/log_viewer_$$"
LINES_PER_PAGE=20
DEFAULT_TAIL_LINES=100

# Create temp directory
mkdir -p "$TEMP_DIR"
trap "rm -rf $TEMP_DIR" EXIT

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Function to print colored output
print_color() {
    echo -e "${1}${2}${NC}"
}

# Function to print large ASCII headers
print_large_header() {
    local text="$1"
    echo
    print_color "$PURPLE$BOLD" "╔══════════════════════════════════════════════════════════════════════════════╗"
    print_color "$PURPLE$BOLD" "║                                                                              ║"
    printf "${PURPLE}${BOLD}║${NC}  %-76s ${PURPLE}${BOLD}║${NC}\n" "$text"
    print_color "$PURPLE$BOLD" "║                                                                              ║"
    print_color "$PURPLE$BOLD" "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo
}

# Function to print section headers
print_section() {
    echo
    print_color "$CYAN$BOLD" "┌──────────────────────────────────────────────────────────────────────────────┐"
    printf "${CYAN}${BOLD}│${NC}  %-76s ${CYAN}${BOLD}│${NC}\n" "$1"
    print_color "$CYAN$BOLD" "└──────────────────────────────────────────────────────────────────────────────┘"
    echo
}

# Function to print boxed content
print_box() {
    local content="$1"
    local color="${2:-$WHITE}"
    echo
    print_color "$color" "┌────────────────────────────────────────────────────┐"
    printf "${color}│${NC} %-50s ${color}│${NC}\n" "$content"
    print_color "$color" "└────────────────────────────────────────────────────┘"
}

# Function to print success message
print_success() {
    echo -e "${GREEN}${BOLD}✅ $1${NC}"
}

# Function to print error message
print_error() {
    echo -e "${RED}${BOLD}❌ $1${NC}"
}

# Function to print warning message
print_warning() {
    echo -e "${YELLOW}${BOLD}⚠️  $1${NC}"
}

# Function to print info message
print_info() {
    echo -e "${CYAN}${BOLD}ℹ️  $1${NC}"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_warning "Some features require root privileges"
        print_info "Run with: sudo $0 for full functionality"
        echo
    fi
}

# Function to detect OS
detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS="$ID"
        OS_VERSION="$VERSION_ID"
        OS_PRETTY="$PRETTY_NAME"
    else
        OS="unknown"
        OS_VERSION="unknown"
        OS_PRETTY="Unknown OS"
    fi
}

# Function to format bytes to human readable
format_bytes() {
    local bytes=$1
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt 1048576 ]]; then
        echo "$((bytes / 1024))KB"
    elif [[ $bytes -lt 1073741824 ]]; then
        echo "$((bytes / 1048576))MB"
    else
        echo "$((bytes / 1073741824))GB"
    fi
}

# Function to colorize log line based on severity
colorize_log_line() {
    local line="$1"
    
    # Check for different log levels and apply colors
    if echo "$line" | grep -qiE "(error|err|failed|failure|fatal|critical)"; then
        echo -e "${COLOR_ERROR}$line${NC}"
    elif echo "$line" | grep -qiE "(warning|warn)"; then
        echo -e "${COLOR_WARNING}$line${NC}"
    elif echo "$line" | grep -qiE "(info|information|notice)"; then
        echo -e "${COLOR_INFO}$line${NC}"
    elif echo "$line" | grep -qiE "(debug|trace)"; then
        echo -e "${COLOR_DEBUG}$line${NC}"
    else
        echo "$line"
    fi
}

# Function to filter logs by severity
filter_by_severity() {
    local file="$1"
    local severity="$2"
    
    case "$severity" in
        "error")
            grep -iE "(error|err|failed|failure|fatal|critical)" "$file"
            ;;
        "warning")
            grep -iE "(warning|warn)" "$file"
            ;;
        "info")
            grep -iE "(info|information|notice)" "$file"
            ;;
        "all")
            cat "$file"
            ;;
        *)
            cat "$file"
            ;;
    esac
}

# Function to filter logs by time range
filter_by_time() {
    local file="$1"
    local range="$2"
    local temp_file="$TEMP_DIR/time_filtered.log"
    
    case "$range" in
        "1h")
            # Last hour
            awk -v d="$(date -d '1 hour ago' '+%Y-%m-%d %H:%M')" '$0 >= d' "$file" > "$temp_file"
            ;;
        "24h")
            # Last 24 hours
            awk -v d="$(date -d '24 hours ago' '+%Y-%m-%d')" '$0 >= d' "$file" > "$temp_file"
            ;;
        "7d")
            # Last 7 days
            awk -v d="$(date -d '7 days ago' '+%Y-%m-%d')" '$0 >= d' "$file" > "$temp_file"
            ;;
        "all")
            cat "$file" > "$temp_file"
            ;;
        *)
            cat "$file" > "$temp_file"
            ;;
    esac
    
    cat "$temp_file"
}

# ============================================================================
# SYSTEM INFORMATION FUNCTIONS
# ============================================================================

show_system_dashboard() {
    clear
    print_large_header "📊 SYSTEM INFORMATION DASHBOARD"
    
    # OS Information
    print_section "🖥️  OPERATING SYSTEM"
    echo -e "${WHITE}${BOLD}System:${NC} $OS_PRETTY"
    echo -e "${WHITE}${BOLD}Kernel:${NC} $(uname -r)"
    echo -e "${WHITE}${BOLD}Architecture:${NC} $(uname -m)"
    echo -e "${WHITE}${BOLD}Hostname:${NC} $(hostname -f 2>/dev/null || hostname)"
    echo -e "${WHITE}${BOLD}Uptime:${NC} $(uptime -p)"
    
    # CPU Information
    print_section "⚡ CPU INFORMATION"
    echo -e "${WHITE}${BOLD}CPU Model:${NC} $(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    echo -e "${WHITE}${BOLD}CPU Cores:${NC} $(nproc)"
    echo -e "${WHITE}${BOLD}CPU Usage:${NC}"
    
    # Get CPU usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    cpu_bar=$(printf '%.0f' "$cpu_usage" 2>/dev/null || echo "0")
    
    # Draw CPU usage bar
    echo -n "  ["
    for i in {1..50}; do
        if [[ $i -le $((cpu_bar / 2)) ]]; then
            echo -n "█"
        else
            echo -n "░"
        fi
    done
    echo "] ${cpu_usage}%"
    
    # Memory Information
    print_section "💾 MEMORY INFORMATION"
    
    # Get memory info
    mem_total=$(free -b | grep "^Mem:" | awk '{print $2}')
    mem_used=$(free -b | grep "^Mem:" | awk '{print $3}')
    mem_free=$(free -b | grep "^Mem:" | awk '{print $4}')
    mem_percent=$((mem_used * 100 / mem_total))
    
    echo -e "${WHITE}${BOLD}Total Memory:${NC} $(format_bytes $mem_total)"
    echo -e "${WHITE}${BOLD}Used Memory:${NC} $(format_bytes $mem_used) (${mem_percent}%)"
    echo -e "${WHITE}${BOLD}Free Memory:${NC} $(format_bytes $mem_free)"
    
    # Draw memory usage bar
    echo -n "${WHITE}${BOLD}Usage:${NC} ["
    for i in {1..50}; do
        if [[ $i -le $((mem_percent / 2)) ]]; then
            if [[ $mem_percent -gt 80 ]]; then
                echo -ne "${RED}█${NC}"
            elif [[ $mem_percent -gt 60 ]]; then
                echo -ne "${YELLOW}█${NC}"
            else
                echo -ne "${GREEN}█${NC}"
            fi
        else
            echo -n "░"
        fi
    done
    echo "] ${mem_percent}%"
    
    # Swap Information
    swap_total=$(free -b | grep "^Swap:" | awk '{print $2}')
    if [[ $swap_total -gt 0 ]]; then
        swap_used=$(free -b | grep "^Swap:" | awk '{print $3}')
        swap_percent=$((swap_used * 100 / swap_total))
        echo
        echo -e "${WHITE}${BOLD}Swap Total:${NC} $(format_bytes $swap_total)"
        echo -e "${WHITE}${BOLD}Swap Used:${NC} $(format_bytes $swap_used) (${swap_percent}%)"
    fi
    
    # Disk Information
    print_section "💿 DISK USAGE"
    
    # Show main disk usage
    df -h / | tail -1 | while read filesystem size used avail use mounted; do
        echo -e "${WHITE}${BOLD}Filesystem:${NC} $filesystem"
        echo -e "${WHITE}${BOLD}Total Size:${NC} $size"
        echo -e "${WHITE}${BOLD}Used:${NC} $used ($use)"
        echo -e "${WHITE}${BOLD}Available:${NC} $avail"
        
        # Draw disk usage bar
        use_percent=${use%\%}
        echo -n "${WHITE}${BOLD}Usage:${NC} ["
        for i in {1..50}; do
            if [[ $i -le $((use_percent / 2)) ]]; then
                if [[ $use_percent -gt 80 ]]; then
                    echo -ne "${RED}█${NC}"
                elif [[ $use_percent -gt 60 ]]; then
                    echo -ne "${YELLOW}█${NC}"
                else
                    echo -ne "${GREEN}█${NC}"
                fi
            else
                echo -n "░"
            fi
        done
        echo "] ${use}%"
    done
    
    # Network Information
    print_section "🌐 NETWORK INFORMATION"
    
    # Get primary network interface
    primary_iface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [[ -n "$primary_iface" ]]; then
        echo -e "${WHITE}${BOLD}Primary Interface:${NC} $primary_iface"
        ip_addr=$(ip addr show "$primary_iface" | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        echo -e "${WHITE}${BOLD}IP Address:${NC} $ip_addr"
        
        # Get network statistics
        if [[ -f "/sys/class/net/$primary_iface/statistics/rx_bytes" ]]; then
            rx_bytes=$(cat "/sys/class/net/$primary_iface/statistics/rx_bytes")
            tx_bytes=$(cat "/sys/class/net/$primary_iface/statistics/tx_bytes")
            echo -e "${WHITE}${BOLD}Data Received:${NC} $(format_bytes $rx_bytes)"
            echo -e "${WHITE}${BOLD}Data Transmitted:${NC} $(format_bytes $tx_bytes)"
        fi
    fi
    
    # Docker Status
    if command -v docker &> /dev/null; then
        print_section "🐳 DOCKER STATUS"
        
        if systemctl is-active --quiet docker; then
            print_success "Docker is running"
            
            # Count containers
            running_containers=$(docker ps -q 2>/dev/null | wc -l)
            all_containers=$(docker ps -aq 2>/dev/null | wc -l)
            images=$(docker images -q 2>/dev/null | wc -l)
            
            echo -e "${WHITE}${BOLD}Running Containers:${NC} $running_containers"
            echo -e "${WHITE}${BOLD}Total Containers:${NC} $all_containers"
            echo -e "${WHITE}${BOLD}Docker Images:${NC} $images"
            
            # Docker version
            docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
            echo -e "${WHITE}${BOLD}Docker Version:${NC} $docker_version"
        else
            print_warning "Docker is installed but not running"
        fi
    else
        print_info "Docker is not installed"
    fi
    
    # Top Processes
    print_section "🔝 TOP PROCESSES (BY CPU)"
    echo -e "${WHITE}${BOLD}PID     CPU%   MEM%   COMMAND${NC}"
    ps aux --sort=-%cpu | head -6 | tail -5 | awk '{printf "%-7s %-6s %-6s %s\n", $2, $3, $4, $11}'
    
    echo
    print_color "$YELLOW$BOLD" "Press Enter to return to main menu..."
    read
}

# ============================================================================
# DOCKER LOG FUNCTIONS
# ============================================================================

view_docker_logs() {
    clear
    print_large_header "🐳 DOCKER CONTAINER LOGS"
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        echo
        print_color "$YELLOW$BOLD" "Press Enter to return..."
        read
        return
    fi
    
    if ! systemctl is-active --quiet docker; then
        print_error "Docker service is not running"
        echo
        print_color "$YELLOW$BOLD" "Press Enter to return..."
        read
        return
    fi
    
    # Get all containers (including stopped)
    print_info "Fetching container list..."
    
    # Create container list with status
    containers_list=()
    while IFS= read -r line; do
        containers_list+=("$line")
    done < <(docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}" | tail -n +2)
    
    if [[ ${#containers_list[@]} -eq 0 ]]; then
        print_warning "No containers found"
        echo
        print_color "$YELLOW$BOLD" "Press Enter to return..."
        read
        return
    fi
    
    # Display container selection menu
    print_section "SELECT CONTAINER"
    
    echo -e "${WHITE}${BOLD}Available Containers:${NC}"
    echo
    echo -e "${CYAN}${BOLD}  #   ID          NAME                    STATUS              IMAGE${NC}"
    echo -e "${CYAN}────────────────────────────────────────────────────────────────────────────${NC}"
    
    index=1
    for container in "${containers_list[@]}"; do
        # Parse container info
        container_id=$(echo "$container" | awk '{print $1}')
        container_name=$(echo "$container" | awk '{print $2}')
        container_status=$(echo "$container" | awk '{print $3}')
        container_image=$(echo "$container" | awk '{print $NF}')
        
        # Color code based on status
        if [[ "$container_status" == "Up" ]]; then
            status_color="${GREEN}"
            status_icon="🟢"
        elif [[ "$container_status" == "Exited" ]]; then
            status_color="${RED}"
            status_icon="🔴"
        else
            status_color="${YELLOW}"
            status_icon="🟡"
        fi
        
        printf "  %-3s %-11s %-23s ${status_color}%-18s${NC} %s\n" \
            "[$index]" "$container_id" "$container_name" "$status_icon $container_status" "$container_image"
        
        ((index++))
    done
    
    echo
    print_color "$CYAN$BOLD" "  [0] Return to main menu"
    echo
    
    # Get user selection
    read -p "$(print_color "$YELLOW$BOLD" "Select container number: ")" selection
    
    if [[ "$selection" == "0" ]]; then
        return
    fi
    
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ $selection -lt 1 ]] || [[ $selection -gt ${#containers_list[@]} ]]; then
        print_error "Invalid selection"
        sleep 2
        view_docker_logs
        return
    fi
    
    # Get selected container info
    selected_container="${containers_list[$((selection-1))]}"
    container_id=$(echo "$selected_container" | awk '{print $1}')
    container_name=$(echo "$selected_container" | awk '{print $2}')
    
    # Log viewing options
    while true; do
        clear
        print_large_header "📋 CONTAINER: $container_name"
        
        print_section "LOG VIEWING OPTIONS"
        
        echo -e "${CYAN}${BOLD}  [1]${NC} View last 50 lines"
        echo -e "${CYAN}${BOLD}  [2]${NC} View last 100 lines"
        echo -e "${CYAN}${BOLD}  [3]${NC} View last 500 lines"
        echo -e "${CYAN}${BOLD}  [4]${NC} Filter by severity (ERROR/WARNING/INFO)"
        echo -e "${CYAN}${BOLD}  [5]${NC} Search for keyword"
        echo -e "${CYAN}${BOLD}  [6]${NC} View logs from last hour"
        echo -e "${CYAN}${BOLD}  [7]${NC} View logs from last 24 hours"
        echo -e "${CYAN}${BOLD}  [8]${NC} Export logs to file"
        echo -e "${RED}${BOLD}  [0]${NC} Back to container selection"
        echo
        
        read -p "$(print_color "$YELLOW$BOLD" "Select option: ")" log_option
        
        case $log_option in
            1)
                clear
                print_section "LAST 50 LINES - $container_name"
                docker logs --tail 50 "$container_id" 2>&1 | while IFS= read -r line; do
                    colorize_log_line "$line"
                done
                echo
                print_color "$YELLOW$BOLD" "Press Enter to continue..."
                read
                ;;
            2)
                clear
                print_section "LAST 100 LINES - $container_name"
                docker logs --tail 100 "$container_id" 2>&1 | while IFS= read -r line; do
                    colorize_log_line "$line"
                done
                echo
                print_color "$YELLOW$BOLD" "Press Enter to continue..."
                read
                ;;
            3)
                clear
                print_section "LAST 500 LINES - $container_name"
                docker logs --tail 500 "$container_id" 2>&1 | while IFS= read -r line; do
                    colorize_log_line "$line"
                done
                echo
                print_color "$YELLOW$BOLD" "Press Enter to continue..."
                read
                ;;
            4)
                clear
                print_section "FILTER BY SEVERITY - $container_name"
                echo -e "${CYAN}${BOLD}  [1]${NC} Show only ERRORS"
                echo -e "${CYAN}${BOLD}  [2]${NC} Show only WARNINGS"
                echo -e "${CYAN}${BOLD}  [3]${NC} Show only INFO"
                echo -e "${CYAN}${BOLD}  [4]${NC} Show ERRORS and WARNINGS"
                echo
                read -p "$(print_color "$YELLOW$BOLD" "Select filter: ")" filter_choice
                
                clear
                case $filter_choice in
                    1)
                        print_section "ERRORS ONLY - $container_name"
                        docker logs "$container_id" 2>&1 | grep -iE "(error|err|failed|failure|fatal|critical)" | tail -100 | while IFS= read -r line; do
                            echo -e "${COLOR_ERROR}$line${NC}"
                        done
                        ;;
                    2)
                        print_section "WARNINGS ONLY - $container_name"
                        docker logs "$container_id" 2>&1 | grep -iE "(warning|warn)" | tail -100 | while IFS= read -r line; do
                            echo -e "${COLOR_WARNING}$line${NC}"
                        done
                        ;;
                    3)
                        print_section "INFO ONLY - $container_name"
                        docker logs "$container_id" 2>&1 | grep -iE "(info|information|notice)" | tail -100 | while IFS= read -r line; do
                            echo -e "${COLOR_INFO}$line${NC}"
                        done
                        ;;
                    4)
                        print_section "ERRORS AND WARNINGS - $container_name"
                        docker logs "$container_id" 2>&1 | grep -iE "(error|err|failed|failure|fatal|critical|warning|warn)" | tail -100 | while IFS= read -r line; do
                            colorize_log_line "$line"
                        done
                        ;;
                esac
                echo
                print_color "$YELLOW$BOLD" "Press Enter to continue..."
                read
                ;;
            5)
                clear
                print_section "SEARCH LOGS - $container_name"
                read -p "$(print_color "$YELLOW$BOLD" "Enter keyword to search: ")" keyword
                
                if [[ -n "$keyword" ]]; then
                    clear
                    print_section "SEARCH RESULTS FOR: '$keyword'"
                    docker logs "$container_id" 2>&1 | grep -i "$keyword" | tail -100 | while IFS= read -r line; do
                        # Highlight the keyword
                        highlighted_line=$(echo "$line" | sed "s/$keyword/${REVERSE}$keyword${NC}/gi")
                        colorize_log_line "$highlighted_line"
                    done
                fi
                echo
                print_color "$YELLOW$BOLD" "Press Enter to continue..."
                read
                ;;
            6)
                clear
                print_section "LOGS FROM LAST HOUR - $container_name"
                docker logs --since 1h "$container_id" 2>&1 | while IFS= read -r line; do
                    colorize_log_line "$line"
                done
                echo
                print_color "$YELLOW$BOLD" "Press Enter to continue..."
                read
                ;;
            7)
                clear
                print_section "LOGS FROM LAST 24 HOURS - $container_name"
                docker logs --since 24h "$container_id" 2>&1 | while IFS= read -r line; do
                    colorize_log_line "$line"
                done
                echo
                print_color "$YELLOW$BOLD" "Press Enter to continue..."
                read
                ;;
            8)
                export_file="/tmp/${container_name}_logs_$(date +%Y%m%d_%H%M%S).log"
                docker logs "$container_id" &> "$export_file"
                print_success "Logs exported to: $export_file"
                echo
                print_color "$YELLOW$BOLD" "Press Enter to continue..."
                read
                ;;
            0)
                view_docker_logs
                return
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# ============================================================================
# SYSTEM LOG FUNCTIONS
# ============================================================================

view_system_logs() {
    clear
    print_large_header "🖥️ SYSTEM LOGS"
    
    print_section "SELECT LOG TYPE"
    
    echo -e "${CYAN}${BOLD}  [1]${NC} System Log (syslog)"
    echo -e "${CYAN}${BOLD}  [2]${NC} Authentication Log (auth.log)"
    echo -e "${CYAN}${BOLD}  [3]${NC} Kernel Log (kern.log)"
    echo -e "${CYAN}${BOLD}  [4]${NC} Boot Log (dmesg)"
    echo -e "${CYAN}${BOLD}  [5]${NC} Package Manager Log (apt/dpkg)"
    echo -e "${CYAN}${BOLD}  [6]${NC} Cron Job Log"
    echo -e "${CYAN}${BOLD}  [7]${NC} Mail Log"
    echo -e "${CYAN}${BOLD}  [8]${NC} UFW Firewall Log"
    echo -e "${CYAN}${BOLD}  [9]${NC} Failed SSH Attempts"
    echo -e "${RED}${BOLD}  [0]${NC} Return to main menu"
    echo
    
    read -p "$(print_color "$YELLOW$BOLD" "Select log type: ")" log_type
    
    case $log_type in
        1)
            view_log_file "/var/log/syslog" "System Log"
            ;;
        2)
            view_log_file "/var/log/auth.log" "Authentication Log"
            ;;
        3)
            view_log_file "/var/log/kern.log" "Kernel Log"
            ;;
        4)
            clear
            print_section "BOOT LOG (dmesg)"
            dmesg | tail -100 | while IFS= read -r line; do
                colorize_log_line "$line"
            done
            echo
            print_color "$YELLOW$BOLD" "Press Enter to continue..."
            read
            ;;
        5)
            view_log_file "/var/log/apt/history.log" "APT History"
            ;;
        6)
            view_log_file "/var/log/cron.log" "Cron Log" "/var/log/syslog"
            ;;
        7)
            view_log_file "/var/log/mail.log" "Mail Log"
            ;;
        8)
            view_log_file "/var/log/ufw.log" "UFW Firewall Log"
            ;;
        9)
            clear
            print_section "FAILED SSH ATTEMPTS"
            if [[ -f "/var/log/auth.log" ]]; then
                grep "Failed password" /var/log/auth.log | tail -50 | while IFS= read -r line; do
                    echo -e "${COLOR_ERROR}$line${NC}"
                done
            else
                print_warning "Auth log not found"
            fi
            echo
            print_color "$YELLOW$BOLD" "Press Enter to continue..."
            read
            ;;
        0)
            return
            ;;
        *)
            print_error "Invalid option"
            sleep 1
            view_system_logs
            ;;
    esac
}

# Function to view a specific log file with options
view_log_file() {
    local log_file="$1"
    local log_name="$2"
    local fallback_file="${3:-}"
    
    # Check if log file exists
    if [[ ! -f "$log_file" ]]; then
        if [[ -n "$fallback_file" ]] && [[ -f "$fallback_file" ]]; then
            log_file="$fallback_file"
            print_warning "Using fallback log: $fallback_file"
        else
            print_error "Log file not found: $log_file"
            echo
            print_color "$YELLOW$BOLD" "Press Enter to continue..."
            read
            return
        fi
    fi
    
    while true; do
        clear
        print_large_header "📄 $log_name"
        
        # Show file info
        file_size=$(stat -c%s "$log_file")
        file_modified=$(stat -c%y "$log_file" | cut -d' ' -f1,2 | cut -d'.' -f1)
        
        print_info "File: $log_file"
        print_info "Size: $(format_bytes $file_size)"
        print_info "Last Modified: $file_modified"
        echo
        
        print_section "VIEW OPTIONS"
        
        echo -e "${CYAN}${BOLD}  [1]${NC} View last 50 lines"
        echo -e "${CYAN}${BOLD}  [2]${NC} View last 100 lines"
        echo -e "${CYAN}${BOLD}  [3]${NC} View last 500 lines"
        echo -e "${CYAN}${BOLD}  [4]${NC} Filter by severity"
        echo -e "${CYAN}${BOLD}  [5]${NC} Search for keyword"
        echo -e "${CYAN}${BOLD}  [6]${NC} View errors only"
        echo -e "${CYAN}${BOLD}  [7]${NC} View warnings only"
        echo -e "${CYAN}${BOLD}  [8]${NC} Statistics summary"
        echo -e "${RED}${BOLD}  [0]${NC} Back"
        echo
        
        read -p "$(print_color "$YELLOW$BOLD" "Select option: ")" option
        
        case $option in
            1)
                clear
                print_section "LAST 50 LINES - $log_name"
                tail -50 "$log_file" | while IFS= read -r line; do
                    colorize_log_line "$line"
                done
                echo
                print_color "$YELLOW$BOLD" "Press Enter to continue..."
                read
                ;;
            2)
                clear
                print_section "LAST 100 LINES - $log_name"
                tail -100 "$log_file" | while IFS= read -r line; do
                    colorize_log_line "$line"
                done
                echo
                print_color "$YELLOW$BOLD" "Press Enter to continue..."
                read
                ;;
            3)
                clear
                print_section "LAST 500 LINES - $log_name"
                tail -500 "$log_file" | while IFS= read -r line; do
                    colorize_log_line "$line"
                done
                echo
                print_color "$YELLOW$BOLD" "Press Enter to continue..."
                read
                ;;
            4)
                clear
                print_section "FILTER BY SEVERITY"
                echo -e "${CYAN}${BOLD}  [1]${NC} Errors only"
                echo -e "${CYAN}${BOLD}  [2]${NC} Warnings only"
                echo -e "${CYAN}${BOLD}  [3]${NC} Info only"
                echo -e "${CYAN}${BOLD}  [4]${NC} Errors and Warnings"
                echo
                read -p "$(print_color "$YELLOW$BOLD" "Select filter: ")" filter
                
                clear
                case $filter in
                    1)
                        print_section "ERRORS - $log_name"
                        grep -iE "(error|err|failed|failure|fatal|critical)" "$log_file" | tail -100 | while IFS= read -r line; do
                            echo -e "${COLOR_ERROR}$line${NC}"
                        done
                        ;;
                    2)
                        print_section "WARNINGS - $log_name"
                        grep -iE "(warning|warn)" "$log_file" | tail -100 | while IFS= read -r line; do
                            echo -e "${COLOR_WARNING}$line${NC}"
                        done
                        ;;
                    3)
                        print_section "INFO - $log_name"
                        grep -iE "(info|information|notice)" "$log_file" | tail -100 | while IFS= read -r line; do
                            echo -e "${COLOR_INFO}$line${NC}"
                        done
                        ;;
                    4)
                        print_section "ERRORS AND WARNINGS - $log_name"
                        grep -iE "(error|err|failed|failure|fatal|critical|warning|warn)" "$log_file" | tail -100 | while IFS= read -r line; do
                            colorize_log_line "$line"
                        done
                        ;;
                esac
                echo
                print_color "$YELLOW$BOLD" "Press Enter to continue..."
                read
                ;;
            5)
                clear
                print_section "SEARCH LOGS"
                read -p "$(print_color "$YELLOW$BOLD" "Enter keyword to search: ")" keyword
                
                if [[ -n "$keyword" ]]; then
                    clear
                    print_section "SEARCH RESULTS FOR: '$keyword'"
                    grep -i "$keyword" "$log_file" | tail -100 | while IFS= read -r line; do
                        # Highlight keyword
                        highlighted_line=$(echo "$line" | sed "s/$keyword/${REVERSE}$keyword${NC}/gi")
                        colorize_log_line "$highlighted_line"
                    done
                fi
                echo
                print_color "$YELLOW$BOLD" "Press Enter to continue..."
                read
                ;;
            6)
                clear
                print_section "ERRORS ONLY - $log_name"
                grep -iE "(error|err|failed|failure|fatal|critical)" "$log_file" | tail -100 | while IFS= read -r line; do
                    echo -e "${COLOR_ERROR}$line${NC}"
                done
                echo
                print_color "$YELLOW$BOLD" "Press Enter to continue..."
                read
                ;;
            7)
                clear
                print_section "WARNINGS ONLY - $log_name"
                grep -iE "(warning|warn)" "$log_file" | tail -100 | while IFS= read -r line; do
                    echo -e "${COLOR_WARNING}$line${NC}"
                done
                echo
                print_color "$YELLOW$BOLD" "Press Enter to continue..."
                read
                ;;
            8)
                clear
                print_section "LOG STATISTICS - $log_name"
                
                # Count different severity levels
                error_count=$(grep -ciE "(error|err|failed|failure|fatal|critical)" "$log_file" 2>/dev/null || echo "0")
                warning_count=$(grep -ciE "(warning|warn)" "$log_file" 2>/dev/null || echo "0")
                info_count=$(grep -ciE "(info|information|notice)" "$log_file" 2>/dev/null || echo "0")
                total_lines=$(wc -l < "$log_file")
                
                echo -e "${WHITE}${BOLD}Total Lines:${NC} $total_lines"
                echo -e "${COLOR_ERROR}Errors:${NC} $error_count"
                echo -e "${COLOR_WARNING}Warnings:${NC} $warning_count"
                echo -e "${COLOR_INFO}Info Messages:${NC} $info_count"
                echo
                
                # Show most common errors
                if [[ $error_count -gt 0 ]]; then
                    echo -e "${WHITE}${BOLD}Most Common Errors:${NC}"
                    grep -iE "(error|err|failed|failure|fatal|critical)" "$log_file" | \
                        sed 's/.*\(error\|err\|failed\|failure\|fatal\|critical\).*/\1/i' | \
                        sort | uniq -c | sort -rn | head -5
                fi
                
                echo
                print_color "$YELLOW$BOLD" "Press Enter to continue..."
                read
                ;;
            0)
                return
                ;;
            *)
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# ============================================================================
# APPLICATION LOG FUNCTIONS
# ============================================================================

view_application_logs() {
    clear
    print_large_header "📱 APPLICATION LOGS"
    
    # Detect installed applications
    print_info "Detecting installed applications..."
    echo
    
    available_apps=()
    app_count=0
    
    # Check for common applications
    if [[ -d "/var/log/nginx" ]] || [[ -f "/var/log/nginx/access.log" ]]; then
        ((app_count++))
        available_apps+=("nginx")
        echo -e "${CYAN}${BOLD}  [$app_count]${NC} Nginx Web Server"
    fi
    
    if [[ -d "/var/log/apache2" ]] || [[ -f "/var/log/apache2/access.log" ]]; then
        ((app_count++))
        available_apps+=("apache2")
        echo -e "${CYAN}${BOLD}  [$app_count]${NC} Apache Web Server"
    fi
    
    if [[ -d "/var/log/mysql" ]] || [[ -f "/var/log/mysql/error.log" ]]; then
        ((app_count++))
        available_apps+=("mysql")
        echo -e "${CYAN}${BOLD}  [$app_count]${NC} MySQL Database"
    fi
    
    if [[ -f "/var/log/postgresql/postgresql-*.log" ]]; then
        ((app_count++))
        available_apps+=("postgresql")
        echo -e "${CYAN}${BOLD}  [$app_count]${NC} PostgreSQL Database"
    fi
    
    if [[ -f "/var/log/redis/redis-server.log" ]]; then
        ((app_count++))
        available_apps+=("redis")
        echo -e "${CYAN}${BOLD}  [$app_count]${NC} Redis Server"
    fi
    
    if [[ -f "/var/log/mongodb/mongod.log" ]]; then
        ((app_count++))
        available_apps+=("mongodb")
        echo -e "${CYAN}${BOLD}  [$app_count]${NC} MongoDB Database"
    fi
    
    if [[ -f "/var/log/php*.log" ]]; then
        ((app_count++))
        available_apps+=("php")
        echo -e "${CYAN}${BOLD}  [$app_count]${NC} PHP"
    fi
    
    if [[ -f "/var/log/fail2ban.log" ]]; then
        ((app_count++))
        available_apps+=("fail2ban")
        echo -e "${CYAN}${BOLD}  [$app_count]${NC} Fail2ban"
    fi
    
    if [[ $app_count -eq 0 ]]; then
        print_warning "No application logs found"
        echo
        print_color "$YELLOW$BOLD" "Press Enter to return..."
        read
        return
    fi
    
    echo -e "${RED}${BOLD}  [0]${NC} Return to main menu"
    echo
    
    read -p "$(print_color "$YELLOW$BOLD" "Select application: ")" app_choice
    
    if [[ "$app_choice" == "0" ]]; then
        return
    fi
    
    if [[ $app_choice -lt 1 ]] || [[ $app_choice -gt $app_count ]]; then
        print_error "Invalid selection"
        sleep 2
        view_application_logs
        return
    fi
    
    selected_app="${available_apps[$((app_choice-1))]}"
    
    case "$selected_app" in
        "nginx")
            view_nginx_logs
            ;;
        "apache2")
            view_apache_logs
            ;;
        "mysql")
            view_mysql_logs
            ;;
        "postgresql")
            view_postgresql_logs
            ;;
        "redis")
            view_log_file "/var/log/redis/redis-server.log" "Redis Server Log"
            ;;
        "mongodb")
            view_log_file "/var/log/mongodb/mongod.log" "MongoDB Log"
            ;;
        "php")
            php_log=$(ls /var/log/php*.log 2>/dev/null | head -1)
            if [[ -n "$php_log" ]]; then
                view_log_file "$php_log" "PHP Error Log"
            fi
            ;;
        "fail2ban")
            view_log_file "/var/log/fail2ban.log" "Fail2ban Log"
            ;;
    esac
}

# Nginx log viewer
view_nginx_logs() {
    clear
    print_large_header "🌐 NGINX LOGS"
    
    print_section "SELECT LOG TYPE"
    
    echo -e "${CYAN}${BOLD}  [1]${NC} Access Log"
    echo -e "${CYAN}${BOLD}  [2]${NC} Error Log"
    echo -e "${CYAN}${BOLD}  [3]${NC} Combined Analysis"
    echo -e "${RED}${BOLD}  [0]${NC} Back"
    echo
    
    read -p "$(print_color "$YELLOW$BOLD" "Select option: ")" nginx_option
    
    case $nginx_option in
        1)
            view_log_file "/var/log/nginx/access.log" "Nginx Access Log"
            ;;
        2)
            view_log_file "/var/log/nginx/error.log" "Nginx Error Log"
            ;;
        3)
            clear
            print_section "NGINX COMBINED ANALYSIS"
            
            if [[ -f "/var/log/nginx/access.log" ]]; then
                echo -e "${WHITE}${BOLD}Top 10 Requested URLs:${NC}"
                awk '{print $7}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -10
                echo
                
                echo -e "${WHITE}${BOLD}Top 10 Client IPs:${NC}"
                awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -10
                echo
                
                echo -e "${WHITE}${BOLD}HTTP Status Codes:${NC}"
                awk '{print $9}' /var/log/nginx/access.log | sort | uniq -c | sort -rn
                echo
            fi
            
            if [[ -f "/var/log/nginx/error.log" ]]; then
                echo -e "${WHITE}${BOLD}Recent Errors:${NC}"
                tail -10 /var/log/nginx/error.log | while IFS= read -r line; do
                    colorize_log_line "$line"
                done
            fi
            
            echo
            print_color "$YELLOW$BOLD" "Press Enter to continue..."
            read
            ;;
        0)
            view_application_logs
            ;;
    esac
}

# Apache log viewer
view_apache_logs() {
    clear
    print_large_header "🌐 APACHE LOGS"
    
    print_section "SELECT LOG TYPE"
    
    echo -e "${CYAN}${BOLD}  [1]${NC} Access Log"
    echo -e "${CYAN}${BOLD}  [2]${NC} Error Log"
    echo -e "${RED}${BOLD}  [0]${NC} Back"
    echo
    
    read -p "$(print_color "$YELLOW$BOLD" "Select option: ")" apache_option
    
    case $apache_option in
        1)
            view_log_file "/var/log/apache2/access.log" "Apache Access Log"
            ;;
        2)
            view_log_file "/var/log/apache2/error.log" "Apache Error Log"
            ;;
        0)
            view_application_logs
            ;;
    esac
}

# MySQL log viewer
view_mysql_logs() {
    clear
    print_large_header "🗄️ MYSQL LOGS"
    
    # Find MySQL log files
    mysql_error_log="/var/log/mysql/error.log"
    mysql_general_log="/var/log/mysql/mysql.log"
    mysql_slow_log="/var/log/mysql/slow.log"
    
    print_section "SELECT LOG TYPE"
    
    if [[ -f "$mysql_error_log" ]]; then
        echo -e "${CYAN}${BOLD}  [1]${NC} Error Log"
    fi
    if [[ -f "$mysql_general_log" ]]; then
        echo -e "${CYAN}${BOLD}  [2]${NC} General Query Log"
    fi
    if [[ -f "$mysql_slow_log" ]]; then
        echo -e "${CYAN}${BOLD}  [3]${NC} Slow Query Log"
    fi
    echo -e "${RED}${BOLD}  [0]${NC} Back"
    echo
    
    read -p "$(print_color "$YELLOW$BOLD" "Select option: ")" mysql_option
    
    case $mysql_option in
        1)
            view_log_file "$mysql_error_log" "MySQL Error Log"
            ;;
        2)
            view_log_file "$mysql_general_log" "MySQL General Log"
            ;;
        3)
            view_log_file "$mysql_slow_log" "MySQL Slow Query Log"
            ;;
        0)
            view_application_logs
            ;;
    esac
}

# PostgreSQL log viewer
view_postgresql_logs() {
    clear
    print_large_header "🗄️ POSTGRESQL LOGS"
    
    # Find PostgreSQL log file
    pg_log=$(ls -t /var/log/postgresql/postgresql-*.log 2>/dev/null | head -1)
    
    if [[ -n "$pg_log" ]]; then
        view_log_file "$pg_log" "PostgreSQL Log"
    else
        print_error "PostgreSQL log file not found"
        echo
        print_color "$YELLOW$BOLD" "Press Enter to continue..."
        read
    fi
}

# ============================================================================
# LOG MANAGEMENT FUNCTIONS
# ============================================================================

manage_logs() {
    clear
    print_large_header "🔧 LOG MANAGEMENT"
    
    print_section "MANAGEMENT OPTIONS"
    
    echo -e "${CYAN}${BOLD}  [1]${NC} View disk usage by logs"
    echo -e "${CYAN}${BOLD}  [2]${NC} Clear old system logs (older than 30 days)"
    echo -e "${CYAN}${BOLD}  [3]${NC} Clear old Docker logs"
    echo -e "${CYAN}${BOLD}  [4]${NC} Rotate logs now"
    echo -e "${CYAN}${BOLD}  [5]${NC} Configure log rotation"
    echo -e "${CYAN}${BOLD}  [6]${NC} Archive logs"
    echo -e "${RED}${BOLD}  [0]${NC} Return to main menu"
    echo
    
    read -p "$(print_color "$YELLOW$BOLD" "Select option: ")" mgmt_option
    
    case $mgmt_option in
        1)
            clear
            print_section "LOG DISK USAGE"
            
            echo -e "${WHITE}${BOLD}Total /var/log usage:${NC}"
            du -sh /var/log 2>/dev/null
            echo
            
            echo -e "${WHITE}${BOLD}Top 10 largest log files:${NC}"
            find /var/log -type f -exec du -h {} + 2>/dev/null | sort -rh | head -10
            echo
            
            if command -v docker &> /dev/null; then
                echo -e "${WHITE}${BOLD}Docker logs usage:${NC}"
                docker system df 2>/dev/null | grep -E "Local Volumes|VOLUME"
            fi
            
            echo
            print_color "$YELLOW$BOLD" "Press Enter to continue..."
            read
            ;;
        2)
            clear
            print_section "CLEAR OLD SYSTEM LOGS"
            
            print_warning "This will delete log files older than 30 days"
            read -p "$(print_color "$YELLOW$BOLD" "Continue? (y/N): ")" confirm
            
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                # Find and delete old logs
                find /var/log -type f -name "*.log.*" -mtime +30 -delete 2>/dev/null
                find /var/log -type f -name "*.gz" -mtime +30 -delete 2>/dev/null
                
                print_success "Old log files cleared"
                
                # Run logrotate
                if command -v logrotate &> /dev/null; then
                    logrotate -f /etc/logrotate.conf
                    print_success "Log rotation completed"
                fi
            else
                print_info "Operation cancelled"
            fi
            
            echo
            print_color "$YELLOW$BOLD" "Press Enter to continue..."
            read
            ;;
        3)
            clear
            print_section "CLEAR DOCKER LOGS"
            
            if ! command -v docker &> /dev/null; then
                print_error "Docker is not installed"
                echo
                print_color "$YELLOW$BOLD" "Press Enter to continue..."
                read
                return
            fi
            
            print_warning "This will truncate logs for all Docker containers"
            read -p "$(print_color "$YELLOW$BOLD" "Continue? (y/N): ")" confirm
            
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                # Truncate logs for all containers
                docker ps -aq | while read container_id; do
                    log_file=$(docker inspect --format='{{.LogPath}}' "$container_id" 2>/dev/null)
                    if [[ -n "$log_file" ]] && [[ -f "$log_file" ]]; then
                        truncate -s 0 "$log_file"
                        container_name=$(docker inspect --format='{{.Name}}' "$container_id" | sed 's/^\/\///')
                        print_success "Cleared logs for: $container_name"
                    fi
                done
                
                # Clean up unused Docker resources
                docker system prune -f --volumes 2>/dev/null
                print_success "Docker cleanup completed"
            else
                print_info "Operation cancelled"
            fi
            
            echo
            print_color "$YELLOW$BOLD" "Press Enter to continue..."
            read
            ;;
        4)
            clear
            print_section "ROTATE LOGS NOW"
            
            if command -v logrotate &> /dev/null; then
                print_info "Running log rotation..."
                logrotate -f /etc/logrotate.conf
                print_success "Log rotation completed"
            else
                print_error "logrotate is not installed"
                print_info "Install with: apt install logrotate"
            fi
            
            echo
            print_color "$YELLOW$BOLD" "Press Enter to continue..."
            read
            ;;
        5)
            clear
            print_section "LOG ROTATION CONFIGURATION"
            
            if [[ -f "/etc/logrotate.conf" ]]; then
                echo -e "${WHITE}${BOLD}Current configuration:${NC}"
                grep -E "^(weekly|daily|monthly|rotate|compress|size)" /etc/logrotate.conf
                echo
                
                print_info "Edit /etc/logrotate.conf to modify rotation settings"
                print_info "Edit /etc/logrotate.d/* for application-specific settings"
            else
                print_error "logrotate configuration not found"
            fi
            
            echo
            print_color "$YELLOW$BOLD" "Press Enter to continue..."
            read
            ;;
        6)
            clear
            print_section "ARCHIVE LOGS"
            
            archive_name="logs_archive_$(date +%Y%m%d_%H%M%S).tar.gz"
            archive_path="/tmp/$archive_name"
            
            print_info "Creating log archive..."
            
            # Create archive
            tar -czf "$archive_path" \
                /var/log/*.log \
                /var/log/syslog* \
                /var/log/auth.log* \
                /var/log/kern.log* \
                2>/dev/null
            
            if [[ -f "$archive_path" ]]; then
                archive_size=$(stat -c%s "$archive_path")
                print_success "Archive created: $archive_path"
                print_info "Size: $(format_bytes $archive_size)"
            else
                print_error "Failed to create archive"
            fi
            
            echo
            print_color "$YELLOW$BOLD" "Press Enter to continue..."
            read
            ;;
        0)
            return
            ;;
        *)
            print_error "Invalid option"
            sleep 1
            manage_logs
            ;;
    esac
}

# ============================================================================
# MAIN MENU
# ============================================================================

show_main_menu() {
    clear
    
    # Large ASCII header for better visibility
    echo
    echo -e "${PURPLE}${BOLD}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}${BOLD}║                                                                              ║${NC}"
    echo -e "${PURPLE}${BOLD}║${NC}  ${WHITE}${BOLD}██╗      ██████╗  ██████╗    ██╗   ██╗██╗███████╗██╗    ██╗███████╗██████╗${NC} ${PURPLE}${BOLD}║${NC}"
    echo -e "${PURPLE}${BOLD}║${NC}  ${WHITE}${BOLD}██║     ██╔═══██╗██╔════╝    ██║   ██║██║██╔════╝██║    ██║██╔════╝██╔══██╗${NC}${PURPLE}${BOLD}║${NC}"
    echo -e "${PURPLE}${BOLD}║${NC}  ${WHITE}${BOLD}██║     ██║   ██║██║  ███╗   ██║   ██║██║█████╗  ██║ █╗ ██║█████╗  ██████╔╝${NC}${PURPLE}${BOLD}║${NC}"
    echo -e "${PURPLE}${BOLD}║${NC}  ${WHITE}${BOLD}██║     ██║   ██║██║   ██║   ╚██╗ ██╔╝██║██╔══╝  ██║███╗██║██╔══╝  ██╔══██╗${NC}${PURPLE}${BOLD}║${NC}"
    echo -e "${PURPLE}${BOLD}║${NC}  ${WHITE}${BOLD}███████╗╚██████╔╝╚██████╔╝    ╚████╔╝ ██║███████╗╚███╔███╔╝███████╗██║  ██║${NC}${PURPLE}${BOLD}║${NC}"
    echo -e "${PURPLE}${BOLD}║${NC}  ${WHITE}${BOLD}╚══════╝ ╚═════╝  ╚═════╝      ╚═══╝  ╚═╝╚══════╝ ╚══╝╚══╝ ╚══════╝╚═╝  ╚═╝${NC}${PURPLE}${BOLD}║${NC}"
    echo -e "${PURPLE}${BOLD}║                                                                              ║${NC}"
    echo -e "${PURPLE}${BOLD}║${NC}                  ${CYAN}${BOLD}System Monitor & Log Analysis Tool v${SCRIPT_VERSION}${NC}                  ${PURPLE}${BOLD}║${NC}"
    echo -e "${PURPLE}${BOLD}║                                                                              ║${NC}"
    echo -e "${PURPLE}${BOLD}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # System status bar
    print_color "$YELLOW$BOLD" "┌──────────────────────────────────────────────────────────────────────────────┐"
    printf "${YELLOW}${BOLD}│${NC} ${WHITE}System: %-20s User: %-10s Date: %-19s${NC} ${YELLOW}${BOLD}│${NC}\n" \
        "$OS_PRETTY" "$(whoami)" "$(date '+%Y-%m-%d %H:%M')"
    print_color "$YELLOW$BOLD" "└──────────────────────────────────────────────────────────────────────────────┘"
    
    echo
    echo
    
    # Menu options with large boxes
    print_color "$WHITE$BOLD" "                           📋 MAIN MENU"
    echo
    echo
    
    print_color "$CYAN$BOLD" "        ┌─────────────────────────────────────────────────────┐"
    print_color "$CYAN$BOLD" "        │  [1]  📊  System Information Dashboard             │"
    print_color "$CYAN$BOLD" "        └─────────────────────────────────────────────────────┘"
    echo
    
    print_color "$CYAN$BOLD" "        ┌─────────────────────────────────────────────────────┐"
    print_color "$CYAN$BOLD" "        │  [2]  🐳  Docker Container Logs                    │"
    print_color "$CYAN$BOLD" "        └─────────────────────────────────────────────────────┘"
    echo
    
    print_color "$CYAN$BOLD" "        ┌─────────────────────────────────────────────────────┐"
    print_color "$CYAN$BOLD" "        │  [3]  🖥️   System Logs                              │"
    print_color "$CYAN$BOLD" "        └─────────────────────────────────────────────────────┘"
    echo
    
    print_color "$CYAN$BOLD" "        ┌─────────────────────────────────────────────────────┐"
    print_color "$CYAN$BOLD" "        │  [4]  📱  Application Logs                         │"
    print_color "$CYAN$BOLD" "        └─────────────────────────────────────────────────────┘"
    echo
    
    print_color "$CYAN$BOLD" "        ┌─────────────────────────────────────────────────────┐"
    print_color "$CYAN$BOLD" "        │  [5]  🔧  Log Management & Cleanup                 │"
    print_color "$CYAN$BOLD" "        └─────────────────────────────────────────────────────┘"
    echo
    
    print_color "$RED$BOLD" "        ┌─────────────────────────────────────────────────────┐"
    print_color "$RED$BOLD" "        │  [0]  ❌  Exit                                     │"
    print_color "$RED$BOLD" "        └─────────────────────────────────────────────────────┘"
    
    echo
    echo
}

# ============================================================================
# MAIN FUNCTION
# ============================================================================

main() {
    # Initialize
    check_root
    detect_os
    
    # Main loop
    while true; do
        show_main_menu
        
        read -p "$(print_color "$YELLOW$BOLD" "        Select option [0-5]: ")" choice
        
        case $choice in
            1)
                show_system_dashboard
                ;;
            2)
                view_docker_logs
                ;;
            3)
                view_system_logs
                ;;
            4)
                view_application_logs
                ;;
            5)
                manage_logs
                ;;
            0)
                clear
                print_large_header "👋 GOODBYE!"
                print_success "Thank you for using Log Viewer & System Monitor!"
                echo
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 0-5."
                sleep 2
                ;;
        esac
    done
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

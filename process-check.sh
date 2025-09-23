#!/bin/bash
# Process Check Script - Enhanced for Myopia Users
# Part of VPS Security Tools Suite
# Host as: process-check.sh

# Enhanced Colors for Better Visibility
RED='\033[1;91m'       # Bright Red
GREEN='\033[1;92m'     # Bright Green  
YELLOW='\033[1;93m'    # Bright Yellow
BLUE='\033[1;94m'      # Bright Blue
CYAN='\033[1;96m'      # Bright Cyan
MAGENTA='\033[1;95m'   # Bright Magenta
WHITE='\033[1;97m'     # Bright White
ORANGE='\033[38;5;208m' # Orange
PURPLE='\033[38;5;135m' # Purple
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'           # No Color
BG_RED='\033[41m'      # Red Background
BG_GREEN='\033[42m'    # Green Background
BG_YELLOW='\033[43m'   # Yellow Background

# Unicode symbols for better visibility
CHECK="✓"
CROSS="✗"
WARNING="⚠"
INFO="ℹ"
ARROW="→"
BULLET="●"
STAR="★"

# Function to print section headers
print_header() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}  $1${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to print sub-headers
print_subheader() {
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  ${STAR} $1${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Function to display system overview
show_system_overview() {
    print_header "SYSTEM OVERVIEW"
    
    # System Info
    echo -e "${WHITE}${BOLD}System Information:${NC}"
    echo -e "${BLUE}  ${BULLET} Hostname:${NC} ${GREEN}$(hostname)${NC}"
    echo -e "${BLUE}  ${BULLET} Kernel:${NC} ${GREEN}$(uname -r)${NC}"
    echo -e "${BLUE}  ${BULLET} Uptime:${NC} ${GREEN}$(uptime -p)${NC}"
    echo ""
    
    # Resource Usage with color coding
    echo -e "${WHITE}${BOLD}Resource Usage:${NC}"
    
    # CPU Usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    if (( $(echo "$cpu_usage > 80" | bc -l 2>/dev/null || echo 0) )); then
        cpu_color="${RED}"
        cpu_status="${CROSS}"
    elif (( $(echo "$cpu_usage > 50" | bc -l 2>/dev/null || echo 0) )); then
        cpu_color="${YELLOW}"
        cpu_status="${WARNING}"
    else
        cpu_color="${GREEN}"
        cpu_status="${CHECK}"
    fi
    echo -e "${BLUE}  ${BULLET} CPU Usage:${NC} ${cpu_color}${cpu_usage}% ${cpu_status}${NC}"
    
    # Memory Usage
    mem_info=$(free -h | grep "^Mem:")
    mem_total=$(echo $mem_info | awk '{print $2}')
    mem_used=$(echo $mem_info | awk '{print $3}')
    mem_percent=$(free | grep "^Mem:" | awk '{printf("%.1f", $3/$2 * 100)}')
    
    if (( $(echo "$mem_percent > 80" | bc -l 2>/dev/null || echo 0) )); then
        mem_color="${RED}"
        mem_status="${CROSS}"
    elif (( $(echo "$mem_percent > 60" | bc -l 2>/dev/null || echo 0) )); then
        mem_color="${YELLOW}"
        mem_status="${WARNING}"
    else
        mem_color="${GREEN}"
        mem_status="${CHECK}"
    fi
    echo -e "${BLUE}  ${BULLET} Memory:${NC} ${mem_color}${mem_used}/${mem_total} (${mem_percent}%) ${mem_status}${NC}"
    
    # Load Average
    load_avg=$(uptime | awk -F'load average:' '{print $2}')
    echo -e "${BLUE}  ${BULLET} Load Average:${NC} ${WHITE}${load_avg}${NC}"
    
    # Process Count
    total_procs=$(ps aux | wc -l)
    running_procs=$(ps r | wc -l)
    echo -e "${BLUE}  ${BULLET} Processes:${NC} ${WHITE}${total_procs} total, ${running_procs} running${NC}"
}

# Function to show top processes
show_top_processes() {
    print_subheader "TOP CPU CONSUMERS"
    
    echo -e "${WHITE}${BOLD}  PID    USER      CPU%   MEM%   COMMAND${NC}"
    echo -e "${DIM}  ───────────────────────────────────────────────────────────${NC}"
    
    ps aux --sort=-%cpu | head -6 | tail -5 | while read user pid cpu mem vsz rss tty stat start time cmd; do
        # Color code based on CPU usage
        if (( $(echo "$cpu > 50" | bc -l 2>/dev/null || echo 0) )); then
            color="${RED}"
            indicator="${WARNING}"
        elif (( $(echo "$cpu > 20" | bc -l 2>/dev/null || echo 0) )); then
            color="${YELLOW}"
            indicator="${BULLET}"
        else
            color="${WHITE}"
            indicator=" "
        fi
        
        # Truncate command for readability
        cmd_short=$(echo "$cmd" | cut -c1-40)
        printf "${color}${indicator} %-7s %-9s %5.1f  %5.1f  %-40s${NC}\n" "$pid" "$user" "$cpu" "$mem" "$cmd_short"
    done
    
    echo ""
    print_subheader "TOP MEMORY CONSUMERS"
    
    echo -e "${WHITE}${BOLD}  PID    USER      CPU%   MEM%   COMMAND${NC}"
    echo -e "${DIM}  ───────────────────────────────────────────────────────────${NC}"
    
    ps aux --sort=-%mem | head -6 | tail -5 | while read user pid cpu mem vsz rss tty stat start time cmd; do
        # Color code based on memory usage
        if (( $(echo "$mem > 30" | bc -l 2>/dev/null || echo 0) )); then
            color="${RED}"
            indicator="${WARNING}"
        elif (( $(echo "$mem > 10" | bc -l 2>/dev/null || echo 0) )); then
            color="${YELLOW}"
            indicator="${BULLET}"
        else
            color="${WHITE}"
            indicator=" "
        fi
        
        cmd_short=$(echo "$cmd" | cut -c1-40)
        printf "${color}${indicator} %-7s %-9s %5.1f  %5.1f  %-40s${NC}\n" "$pid" "$user" "$cpu" "$mem" "$cmd_short"
    done
}

# Function to check suspicious processes
check_suspicious_processes() {
    print_subheader "SECURITY ANALYSIS"
    
    # Known suspicious patterns
    suspicious_patterns="xmrig|minergate|minerd|cpuminer|cryptonight|monero|kworkerds|kdevtmpfsi|kinsing|ddgs|qW3xT|2t3ik|dbused|xmr|crypto-pool|minexmr|pool.min"
    
    echo -e "${WHITE}${BOLD}Checking for suspicious processes...${NC}"
    echo ""
    
    suspicious_found=0
    
    # Check running processes
    for pattern in $(echo $suspicious_patterns | tr '|' ' '); do
        if pgrep -f "$pattern" >/dev/null 2>&1; then
            suspicious_found=1
            pids=$(pgrep -f "$pattern")
            echo -e "${BG_RED}${WHITE}${BOLD} ${CROSS} THREAT DETECTED ${NC}"
            echo -e "${RED}${BOLD}  Pattern: ${pattern}${NC}"
            echo -e "${RED}  PIDs: ${pids}${NC}"
            
            for pid in $pids; do
                if [ -r "/proc/$pid/cmdline" ]; then
                    cmd=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null | cut -c1-60)
                    echo -e "${YELLOW}  ${ARROW} ${cmd}${NC}"
                fi
            done
            echo ""
        fi
    done
    
    if [ $suspicious_found -eq 0 ]; then
        echo -e "${GREEN}${CHECK} No suspicious processes detected${NC}"
    else
        echo -e "${RED}${BOLD}${WARNING} Action Required:${NC}"
        echo -e "${YELLOW}  1. Kill suspicious processes immediately${NC}"
        echo -e "${YELLOW}  2. Check for persistence mechanisms${NC}"
        echo -e "${YELLOW}  3. Review system logs${NC}"
    fi
    
    # Check for fake kernel threads
    echo ""
    echo -e "${WHITE}${BOLD}Checking for fake kernel threads...${NC}"
    echo ""
    
    fake_found=0
    ps aux | grep -E "\[.*\]" | while read line; do
        pid=$(echo "$line" | awk '{print $2}')
        cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i}')
        
        if [ -d "/proc/$pid" ] && [ -r "/proc/$pid/exe" ]; then
            exe=$(readlink -f /proc/$pid/exe 2>/dev/null)
            if [ -n "$exe" ] && [ "$exe" != "[kernel]" ]; then
                fake_found=1
                echo -e "${RED}${WARNING} Suspicious kernel thread: PID $pid${NC}"
                echo -e "${YELLOW}  Command: ${cmd}${NC}"
                echo -e "${YELLOW}  Exe: ${exe}${NC}"
            fi
        fi
    done
    
    if [ $fake_found -eq 0 ]; then
        echo -e "${GREEN}${CHECK} No fake kernel threads detected${NC}"
    fi
}

# Function to show service status
show_service_status() {
    print_subheader "SYSTEM SERVICES STATUS"
    
    # Critical services to check
    critical_services="ssh sshd nginx apache2 httpd mysql mariadb postgresql docker fail2ban ufw firewalld"
    
    echo -e "${WHITE}${BOLD}Critical Services:${NC}"
    echo ""
    
    for service in $critical_services; do
        if systemctl list-unit-files | grep -q "^${service}\.service"; then
            status=$(systemctl is-active "$service" 2>/dev/null)
            enabled=$(systemctl is-enabled "$service" 2>/dev/null)
            
            if [ "$status" = "active" ]; then
                status_color="${GREEN}"
                status_icon="${CHECK}"
            elif [ "$status" = "inactive" ]; then
                status_color="${DIM}"
                status_icon="-"
            else
                status_color="${RED}"
                status_icon="${CROSS}"
            fi
            
            if [ "$enabled" = "enabled" ]; then
                enabled_color="${GREEN}"
            else
                enabled_color="${DIM}"
            fi
            
            printf "  ${status_color}${status_icon}${NC} %-15s ${status_color}[%-8s]${NC} ${enabled_color}[%-8s]${NC}\n" \
                   "$service" "$status" "$enabled"
        fi
    done
    
    # Show failed services
    echo ""
    echo -e "${WHITE}${BOLD}Failed Services:${NC}"
    echo ""
    
    failed_services=$(systemctl list-units --state=failed --no-pager --no-legend 2>/dev/null)
    if [ -z "$failed_services" ]; then
        echo -e "${GREEN}  ${CHECK} No failed services${NC}"
    else
        echo "$failed_services" | while read line; do
            service_name=$(echo "$line" | awk '{print $1}')
            echo -e "${RED}  ${CROSS} ${service_name}${NC}"
        done
    fi
}

# Function for interactive process investigation
investigate_process() {
    local search_term="$1"
    
    print_header "PROCESS INVESTIGATION: $search_term"
    
    # Search for the process
    echo -e "${WHITE}${BOLD}Searching for: ${YELLOW}${search_term}${NC}"
    echo ""
    
    # Find matching processes
    pids=$(pgrep -f "$search_term" 2>/dev/null)
    
    if [ -z "$pids" ]; then
        echo -e "${YELLOW}${INFO} No running processes match '${search_term}'${NC}"
        echo ""
        
        # Check if it's a service
        if systemctl list-unit-files | grep -q "${search_term}"; then
            echo -e "${BLUE}Found as a system service:${NC}"
            systemctl status "${search_term}" --no-pager 2>/dev/null | head -10
        fi
    else
        echo -e "${GREEN}${CHECK} Found process(es): ${pids}${NC}"
        echo ""
        
        for pid in $pids; do
            echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║${WHITE}${BOLD}  PID: ${pid}${CYAN}                                        ║${NC}"
            echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
            echo ""
            
            if [ -d "/proc/$pid" ]; then
                # Basic info
                echo -e "${WHITE}${BOLD}Basic Information:${NC}"
                
                # Command line
                if [ -r "/proc/$pid/cmdline" ]; then
                    cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
                    echo -e "${BLUE}  ${BULLET} Command:${NC} ${cmdline:0:80}"
                fi
                
                # Executable
                if [ -r "/proc/$pid/exe" ]; then
                    exe_path=$(readlink -f /proc/$pid/exe 2>/dev/null)
                    echo -e "${BLUE}  ${BULLET} Executable:${NC} ${exe_path:-[Deleted]}"
                    
                    # Check location
                    if echo "$exe_path" | grep -qE "^(/tmp|/var/tmp|/dev/shm)"; then
                        echo -e "${RED}    ${WARNING} Suspicious location!${NC}"
                    fi
                fi
                
                # User
                if [ -r "/proc/$pid/status" ]; then
                    uid=$(grep "^Uid:" /proc/$pid/status | awk '{print $2}')
                    username=$(id -nu $uid 2>/dev/null || echo "UID:$uid")
                    echo -e "${BLUE}  ${BULLET} User:${NC} ${username}"
                    
                    # Parent process
                    ppid=$(grep "^PPid:" /proc/$pid/status | awk '{print $2}')
                    if [ "$ppid" -ne 0 ]; then
                        parent_cmd=$(ps -p $ppid -o comm= 2>/dev/null)
                        echo -e "${BLUE}  ${BULLET} Parent:${NC} ${parent_cmd} (PID: ${ppid})"
                    fi
                fi
                
                # Resource usage
                echo ""
                echo -e "${WHITE}${BOLD}Resource Usage:${NC}"
                if command -v ps &>/dev/null; then
                    ps_info=$(ps -p $pid -o %cpu,%mem,etime 2>/dev/null | tail -1)
                    cpu=$(echo "$ps_info" | awk '{print $1}')
                    mem=$(echo "$ps_info" | awk '{print $2}')
                    etime=$(echo "$ps_info" | awk '{print $3}')
                    
                    echo -e "${BLUE}  ${BULLET} CPU:${NC} ${cpu}%"
                    echo -e "${BLUE}  ${BULLET} Memory:${NC} ${mem}%"
                    echo -e "${BLUE}  ${BULLET} Runtime:${NC} ${etime}"
                fi
                
                # Network connections
                echo ""
                echo -e "${WHITE}${BOLD}Network Activity:${NC}"
                net_conn=$(sudo lsof -p $pid 2>/dev/null | grep -E "(TCP|UDP)" | head -3)
                if [ -n "$net_conn" ]; then
                    echo "$net_conn" | while read line; do
                        echo -e "${BLUE}  ${ARROW}${NC} ${line}"
                    done
                else
                    echo -e "${DIM}  No network connections${NC}"
                fi
                
                # Open files
                echo ""
                echo -e "${WHITE}${BOLD}Open Files (top 5):${NC}"
                files=$(sudo lsof -p $pid 2>/dev/null | grep -v -E "(TCP|UDP|pipe|socket)" | tail -5)
                if [ -n "$files" ]; then
                    echo "$files" | while read line; do
                        echo -e "${BLUE}  ${ARROW}${NC} ${line:0:70}"
                    done
                else
                    echo -e "${DIM}  No significant files open${NC}"
                fi
            fi
            echo ""
        done
    fi
}

# Main menu function
show_menu() {
    while true; do
        clear
        
        # Header
        echo ""
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}                                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${WHITE}${BOLD}            🔍 PROCESS CHECK & MONITORING TOOL 🔍                 ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Quick system status
        cpu_now=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        mem_percent=$(free | grep "^Mem:" | awk '{printf("%.1f", $3/$2 * 100)}')
        
        echo -e "${WHITE}${BOLD}Quick Status:${NC}"
        echo -e "  ${BLUE}CPU:${NC} ${GREEN}${cpu_now}%${NC}  ${BLUE}Memory:${NC} ${GREEN}${mem_percent}%${NC}  ${BLUE}Uptime:${NC} ${GREEN}$(uptime -p | sed 's/up //')${NC}"
        echo ""
        echo -e "${DIM}══════════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        # Menu options
        echo -e "${WHITE}${BOLD}SELECT AN OPTION:${NC}"
        echo ""
        echo -e "  ${YELLOW}1)${NC} ${WHITE}System Overview${NC} ${DIM}- Resource usage & system info${NC}"
        echo ""
        echo -e "  ${YELLOW}2)${NC} ${WHITE}Top Processes${NC} ${DIM}- CPU & Memory consumers${NC}"
        echo ""
        echo -e "  ${YELLOW}3)${NC} ${WHITE}Service Status${NC} ${DIM}- System services health${NC}"
        echo ""
        echo -e "  ${YELLOW}4)${NC} ${WHITE}Security Check${NC} ${DIM}- Scan for suspicious processes${NC}"
        echo ""
        echo -e "  ${YELLOW}5)${NC} ${WHITE}Investigate Process${NC} ${DIM}- Deep dive into specific process${NC}"
        echo ""
        echo -e "  ${YELLOW}6)${NC} ${WHITE}Full Report${NC} ${DIM}- Complete system analysis${NC}"
        echo ""
        echo -e "  ${YELLOW}R)${NC} ${WHITE}Refresh${NC} ${DIM}- Refresh current view${NC}"
        echo ""
        echo -e "  ${RED}0)${NC} ${WHITE}Exit${NC}"
        echo ""
        echo -e "${DIM}══════════════════════════════════════════════════════════════════${NC}"
        echo ""
        
        read -p "$(echo -e ${YELLOW}${BOLD}'Enter choice: '${NC})" choice
        
        case $choice in
            1)
                clear
                show_system_overview
                ;;
            2)
                clear
                show_top_processes
                ;;
            3)
                clear
                show_service_status
                ;;
            4)
                clear
                check_suspicious_processes
                ;;
            5)
                clear
                echo ""
                read -p "$(echo -e ${YELLOW}${BOLD}'Enter process name or PID to investigate: '${NC})" search_term
                if [ -n "$search_term" ]; then
                    clear
                    investigate_process "$search_term"
                fi
                ;;
            6)
                clear
                show_system_overview
                show_top_processes
                show_service_status
                check_suspicious_processes
                ;;
            r|R)
                continue
                ;;
            0)
                echo ""
                echo -e "${GREEN}${BOLD}Goodbye! Stay secure! 👋${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option!${NC}"
                sleep 1
                continue
                ;;
        esac
        
        echo ""
        echo -e "${DIM}══════════════════════════════════════════════════════════════════${NC}"
        echo ""
        read -p "$(echo -e ${YELLOW}${BOLD}'Press Enter to continue...'${NC})"
    done
}

# Check if running with sufficient privileges for some operations
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}${WARNING} Note: Some features work better with sudo privileges${NC}"
    echo -e "${DIM}Run with: sudo $0${NC}"
    echo ""
fi

# Main execution
show_menu

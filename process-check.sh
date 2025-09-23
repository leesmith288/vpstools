#!/bin/bash
# Process Check Script - Direct Display Version
# Shows all information immediately, then offers actions
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

# Function to print section headers with better visibility
print_section() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}${BOLD}  $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Function to check for suspicious processes
check_suspicious() {
    local suspicious_found=0
    local suspicious_patterns="xmrig|minergate|minerd|cpuminer|cryptonight|monero|kworkerds|kdevtmpfsi|kinsing|ddgs|qW3xT|2t3ik|dbused|xmr|crypto-pool|minexmr|pool.min"
    
    for pattern in $(echo $suspicious_patterns | tr '|' ' '); do
        if pgrep -f "$pattern" >/dev/null 2>&1; then
            if [ $suspicious_found -eq 0 ]; then
                echo ""
                echo -e "${BG_RED}${WHITE}${BOLD} ${WARNING} SECURITY ALERT - SUSPICIOUS PROCESSES DETECTED ${WARNING} ${NC}"
                echo ""
            fi
            suspicious_found=1
            pids=$(pgrep -f "$pattern")
            echo -e "${RED}${BOLD}  ${CROSS} Pattern: ${pattern}${NC}"
            echo -e "${RED}     PIDs: ${pids}${NC}"
        fi
    done
    
    return $suspicious_found
}

# Function to kill a process
kill_process() {
    local pid=$1
    echo ""
    echo -e "${YELLOW}Attempting to kill process ${pid}...${NC}"
    
    # Check if process exists
    if ! ps -p $pid > /dev/null 2>&1; then
        echo -e "${RED}Process $pid does not exist${NC}"
        return 1
    fi
    
    # Get process info before killing
    local pinfo=$(ps -p $pid -o comm=,user=,%cpu=,%mem= 2>/dev/null)
    echo -e "${BLUE}Process info: ${pinfo}${NC}"
    
    # Try graceful termination first
    kill -TERM $pid 2>/dev/null
    sleep 2
    
    if ps -p $pid > /dev/null 2>&1; then
        # Force kill if still running
        echo -e "${YELLOW}Process didn't terminate, forcing...${NC}"
        kill -KILL $pid 2>/dev/null
        sleep 1
        
        if ps -p $pid > /dev/null 2>&1; then
            echo -e "${RED}${CROSS} Failed to kill process $pid${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}${CHECK} Successfully killed process $pid${NC}"
    return 0
}

# Function to show process details
show_process_details() {
    local pid=$1
    
    if [ ! -d "/proc/$pid" ]; then
        echo -e "${RED}Process $pid not found${NC}"
        return
    fi
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}  Process Details for PID: ${pid}${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Command line
    if [ -r "/proc/$pid/cmdline" ]; then
        local cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
        echo -e "${BLUE}${BOLD}Command:${NC}"
        echo -e "  ${WHITE}${cmdline:0:100}${NC}"
        echo ""
    fi
    
    # Executable path
    if [ -r "/proc/$pid/exe" ]; then
        local exe_path=$(readlink -f /proc/$pid/exe 2>/dev/null)
        echo -e "${BLUE}${BOLD}Executable:${NC} ${WHITE}${exe_path:-[Deleted]}${NC}"
        
        if echo "$exe_path" | grep -qE "^(/tmp|/var/tmp|/dev/shm)"; then
            echo -e "${RED}  ${WARNING} Warning: Suspicious location!${NC}"
        fi
        echo ""
    fi
    
    # Process status
    if [ -r "/proc/$pid/status" ]; then
        echo -e "${BLUE}${BOLD}Status Info:${NC}"
        grep -E "^(Name|State|Uid|Gid|PPid|Threads):" /proc/$pid/status | while read line; do
            echo -e "  ${WHITE}${line}${NC}"
        done
        echo ""
    fi
    
    # Network connections
    echo -e "${BLUE}${BOLD}Network Connections:${NC}"
    local net_conn=$(sudo lsof -p $pid 2>/dev/null | grep -E "(TCP|UDP)" | head -5)
    if [ -n "$net_conn" ]; then
        echo "$net_conn" | while read line; do
            echo -e "  ${WHITE}${line:0:80}${NC}"
        done
    else
        echo -e "  ${DIM}No network connections${NC}"
    fi
    echo ""
    
    # Open files (top 5)
    echo -e "${BLUE}${BOLD}Open Files (top 5):${NC}"
    local files=$(sudo lsof -p $pid 2>/dev/null | grep -v -E "(TCP|UDP|pipe|socket)" | tail -5)
    if [ -n "$files" ]; then
        echo "$files" | while read line; do
            echo -e "  ${WHITE}${line:0:80}${NC}"
        done
    else
        echo -e "  ${DIM}No significant files${NC}"
    fi
}

# Main display function
main_display() {
    clear
    
    # Header
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}              PROCESS CHECK & SYSTEM MONITOR                     ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}  $(date '+%Y-%m-%d %H:%M:%S')                                          ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    
    # Quick System Stats
    echo ""
    echo -e "${GREEN}${BOLD}System: ${NC}${WHITE}$(hostname)${NC}  ${GREEN}${BOLD}Kernel: ${NC}${WHITE}$(uname -r)${NC}  ${GREEN}${BOLD}Uptime: ${NC}${WHITE}$(uptime -p | sed 's/up //')${NC}"
    
    # Check for suspicious processes first (alert at top if found)
    check_suspicious
    local has_suspicious=$?
    
    # System Resources
    print_section "SYSTEM RESOURCES"
    free -h | sed 's/^/  /'
    
    # CPU Usage Bar Graph (simple visual)
    echo ""
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo -e "${BLUE}${BOLD}  CPU Usage: ${NC}"
    printf "  ["
    for i in {1..50}; do
        if (( $(echo "$i <= $cpu_usage/2" | bc -l 2>/dev/null || echo 0) )); then
            if (( $(echo "$cpu_usage > 80" | bc -l 2>/dev/null || echo 0) )); then
                printf "${RED}█${NC}"
            elif (( $(echo "$cpu_usage > 50" | bc -l 2>/dev/null || echo 0) )); then
                printf "${YELLOW}█${NC}"
            else
                printf "${GREEN}█${NC}"
            fi
        else
            printf "${DIM}·${NC}"
        fi
    done
    printf "] ${WHITE}${cpu_usage}%%${NC}\n"
    
    # Load Average with color coding
    echo ""
    load_avg=$(cat /proc/loadavg | awk '{print $1, $2, $3}')
    cores=$(nproc)
    echo -e "${BLUE}${BOLD}  Load Average: ${NC}${WHITE}${load_avg}${NC} ${DIM}(${cores} cores)${NC}"
    
    # CPU Processes
    print_section "CPU PROCESSES (>0.1% CPU)"
    echo -e "${WHITE}${BOLD}  PID    PPID   USER      %CPU  %MEM  STAT  START     COMMAND${NC}"
    echo -e "${DIM}  ─────────────────────────────────────────────────────────────────────${NC}"
    ps -eo pid,ppid,user,%cpu,%mem,stat,start,comm --sort=-%cpu | awk 'NR==1 || $4>0.1' | tail -n +2 | head -15 | while read line; do
        cpu_val=$(echo "$line" | awk '{print $4}')
        if (( $(echo "$cpu_val > 50" | bc -l 2>/dev/null || echo 0) )); then
            echo -e "${RED}  ${line}${NC}"
        elif (( $(echo "$cpu_val > 20" | bc -l 2>/dev/null || echo 0) )); then
            echo -e "${YELLOW}  ${line}${NC}"
        else
            echo -e "${WHITE}  ${line}${NC}"
        fi
    done
    
    # Memory Processes
    print_section "MEMORY PROCESSES (>0.1% MEM)"
    echo -e "${WHITE}${BOLD}  PID    PPID   USER      %CPU  %MEM  STAT  START     COMMAND${NC}"
    echo -e "${DIM}  ─────────────────────────────────────────────────────────────────────${NC}"
    ps -eo pid,ppid,user,%cpu,%mem,stat,start,comm --sort=-%mem | awk 'NR==1 || $5>0.1' | tail -n +2 | head -15 | while read line; do
        mem_val=$(echo "$line" | awk '{print $5}')
        if (( $(echo "$mem_val > 30" | bc -l 2>/dev/null || echo 0) )); then
            echo -e "${RED}  ${line}${NC}"
        elif (( $(echo "$mem_val > 10" | bc -l 2>/dev/null || echo 0) )); then
            echo -e "${YELLOW}  ${line}${NC}"
        else
            echo -e "${WHITE}  ${line}${NC}"
        fi
    done
    
    # Running Services
    print_section "RUNNING SERVICES"
    systemctl list-units --type=service --state=running --no-pager | head -20 | tail -n +2 | while read line; do
        if echo "$line" | grep -q "failed\|error"; then
            echo -e "${RED}  ${line}${NC}"
        elif echo "$line" | grep -q "running"; then
            echo -e "${GREEN}  ${line}${NC}"
        else
            echo -e "${WHITE}  ${line}${NC}"
        fi
    done
    
    # Failed Services
    print_section "FAILED SERVICES"
    failed_count=$(systemctl list-units --state=failed --no-legend | wc -l)
    if [ $failed_count -eq 0 ]; then
        echo -e "${GREEN}  ${CHECK} No failed services${NC}"
    else
        systemctl list-units --state=failed --no-pager --no-legend | while read line; do
            echo -e "${RED}  ${CROSS} ${line}${NC}"
        done
    fi
    
    # Summary Statistics
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}  SUMMARY STATISTICS${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    
    total_procs=$(ps aux | wc -l)
    running_procs=$(ps r | wc -l)
    sleeping_procs=$(ps aux | awk '$8 ~ /S/' | wc -l)
    zombie_procs=$(ps aux | awk '$8 ~ /Z/' | wc -l)
    
    echo ""
    echo -e "${BLUE}  Total Processes: ${WHITE}${total_procs}${NC}"
    echo -e "${BLUE}  Running: ${GREEN}${running_procs}${NC}  ${BLUE}Sleeping: ${WHITE}${sleeping_procs}${NC}  ${BLUE}Zombie: ${NC}$([ $zombie_procs -gt 0 ] && echo -e "${RED}${zombie_procs}${NC}" || echo -e "${GREEN}0${NC}")"
    
    if [ $has_suspicious -eq 1 ]; then
        echo ""
        echo -e "${BG_RED}${WHITE}${BOLD}  ${WARNING} SECURITY ISSUES REQUIRE ATTENTION ${WARNING}  ${NC}"
    fi
}

# Interactive actions function
show_actions() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}  AVAILABLE ACTIONS${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${YELLOW}K)${NC} Kill a process by PID"
    echo -e "  ${YELLOW}D)${NC} Show detailed info for a PID"
    echo -e "  ${YELLOW}S)${NC} Search for a process by name"
    echo -e "  ${YELLOW}R)${NC} Refresh display"
    echo -e "  ${YELLOW}E)${NC} Export report to file"
    echo -e "  ${YELLOW}Q)${NC} Quit"
    echo ""
    echo -e "${DIM}────────────────────────────────────────────────────────────────────${NC}"
    echo ""
}

# Search for process function
search_process() {
    local search_term=$1
    echo ""
    echo -e "${CYAN}Searching for: ${YELLOW}${search_term}${NC}"
    echo ""
    
    local results=$(ps aux | grep -i "$search_term" | grep -v grep)
    if [ -z "$results" ]; then
        echo -e "${RED}No processes found matching '${search_term}'${NC}"
    else
        echo -e "${WHITE}${BOLD}USER       PID  %CPU  %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND${NC}"
        echo -e "${DIM}────────────────────────────────────────────────────────────────────${NC}"
        echo "$results" | while read line; do
            echo -e "${WHITE}${line}${NC}"
        done
    fi
}

# Export report function
export_report() {
    local filename="process_report_$(date +%Y%m%d_%H%M%S).txt"
    echo "Generating report..."
    {
        echo "PROCESS CHECK REPORT"
        echo "Generated: $(date)"
        echo "Host: $(hostname)"
        echo "================================"
        echo ""
        echo "SYSTEM RESOURCES:"
        free -h
        echo ""
        echo "CPU PROCESSES:"
        ps -eo pid,ppid,user,%cpu,%mem,stat,start,comm --sort=-%cpu | head -20
        echo ""
        echo "MEMORY PROCESSES:"
        ps -eo pid,ppid,user,%cpu,%mem,stat,start,comm --sort=-%mem | head -20
        echo ""
        echo "SERVICES:"
        systemctl list-units --type=service --state=running --no-pager
        echo ""
        echo "FAILED SERVICES:"
        systemctl list-units --state=failed --no-pager
    } > "$filename"
    
    echo -e "${GREEN}${CHECK} Report saved to: ${WHITE}${filename}${NC}"
}

# Main execution
main() {
    # Show main display first
    main_display
    
    # Then show action menu
    while true; do
        show_actions
        read -p "$(echo -e ${YELLOW}${BOLD}'Select action: '${NC})" action
        
        case ${action,,} in
            k)
                read -p "$(echo -e ${YELLOW}'Enter PID to kill: '${NC})" pid
                if [[ "$pid" =~ ^[0-9]+$ ]]; then
                    kill_process $pid
                else
                    echo -e "${RED}Invalid PID${NC}"
                fi
                echo ""
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                ;;
            d)
                read -p "$(echo -e ${YELLOW}'Enter PID for details: '${NC})" pid
                if [[ "$pid" =~ ^[0-9]+$ ]]; then
                    show_process_details $pid
                else
                    echo -e "${RED}Invalid PID${NC}"
                fi
                echo ""
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                ;;
            s)
                read -p "$(echo -e ${YELLOW}'Enter process name to search: '${NC})" search_term
                if [ -n "$search_term" ]; then
                    search_process "$search_term"
                fi
                echo ""
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                ;;
            r)
                main_display
                ;;
            e)
                export_report
                echo ""
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                ;;
            q)
                echo ""
                echo -e "${GREEN}${BOLD}Goodbye! Stay secure! 👋${NC}"
                echo ""
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

# Check for help flag
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Process Check Script"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -w, --watch    Auto-refresh every 5 seconds"
    echo ""
    exit 0
fi

# Check for watch mode
if [[ "$1" == "-w" ]] || [[ "$1" == "--watch" ]]; then
    while true; do
        main_display
        echo ""
        echo -e "${DIM}Auto-refresh in 5 seconds... Press Ctrl+C to stop${NC}"
        sleep 5
    done
else
    # Normal mode
    main
fi

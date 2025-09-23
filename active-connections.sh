#!/bin/bash
# Active Connections Monitor - Enhanced Version
# Shows all network connections immediately with geographic info
# Part of VPS Security Tools Suite
# Host as: active-connections.sh

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo ""
    echo "⚠️  This script requires sudo privileges for full functionality"
    echo "Please run: sudo $0"
    echo ""
    exit 1
fi

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

# Unicode symbols
CHECK="✓"
CROSS="✗"
WARNING="⚠"
INFO="ℹ"
ARROW="→"
BULLET="●"
GLOBE="🌍"

# Function to print section headers
print_section() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}${BOLD}  $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Function to get IP location
get_ip_location() {
    local ip=$1
    # Skip private IPs
    if echo "$ip" | grep -qE "^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|::1|fe80:)"; then
        echo "Private/Local"
        return
    fi
    
    # Try to get location (with timeout)
    local location=$(timeout 1 curl -s "http://ip-api.com/json/$ip" 2>/dev/null | grep -oP '"country":\s*"\K[^"]+' || echo "Unknown")
    local city=$(timeout 1 curl -s "http://ip-api.com/json/$ip" 2>/dev/null | grep -oP '"city":\s*"\K[^"]+' || echo "")
    
    if [ -n "$city" ] && [ "$city" != "null" ]; then
        echo "$city, $location"
    else
        echo "$location"
    fi
}

# Function to check if IP is suspicious
check_suspicious_ip() {
    local ip=$1
    
    # Check against known bad IPs (you can expand this list)
    local bad_ips="185.220.101 162.247.74 104.244 185.129.62 23.129.64 185.220.102 51.75.64"
    
    for bad in $bad_ips; do
        if echo "$ip" | grep -q "^$bad"; then
            return 0  # Suspicious
        fi
    done
    
    # Check if IP has too many connections
    local conn_count=$(ss -tn | grep "$ip" | wc -l)
    if [ $conn_count -gt 10 ]; then
        return 0  # Suspicious (too many connections)
    fi
    
    return 1  # Not suspicious
}

# Function to kill a connection
kill_connection() {
    local src_ip=$1
    local src_port=$2
    local dst_ip=$3
    local dst_port=$4
    
    echo -e "${YELLOW}Attempting to kill connection...${NC}"
    
    # Use ss to kill the connection
    ss -K dst $dst_ip dport = $dst_port 2>/dev/null
    
    # Alternative: use tcpkill if available
    if command -v tcpkill &> /dev/null; then
        timeout 3 tcpkill -i any host $dst_ip and port $dst_port 2>/dev/null &
    fi
    
    # Alternative: use iptables to block
    echo -e "${YELLOW}Adding temporary firewall rule...${NC}"
    iptables -I INPUT -s $dst_ip -j DROP
    
    echo -e "${GREEN}${CHECK} Connection killed and IP temporarily blocked${NC}"
    echo -e "${DIM}To unblock: iptables -D INPUT -s $dst_ip -j DROP${NC}"
}

# Function to show connection details
show_connection_details() {
    local ip=$1
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}  Connection Details for IP: ${ip}${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Get all connections from this IP
    echo -e "${BLUE}${BOLD}Active Connections:${NC}"
    ss -tn | grep "$ip" | while read line; do
        echo -e "  ${WHITE}${line}${NC}"
    done
    echo ""
    
    # Get location info
    echo -e "${BLUE}${BOLD}Geographic Information:${NC}"
    local full_info=$(curl -s "http://ip-api.com/json/$ip" 2>/dev/null)
    if [ -n "$full_info" ]; then
        echo "  Country: $(echo "$full_info" | grep -oP '"country":\s*"\K[^"]+')"
        echo "  City: $(echo "$full_info" | grep -oP '"city":\s*"\K[^"]+')"
        echo "  ISP: $(echo "$full_info" | grep -oP '"isp":\s*"\K[^"]+')"
        echo "  Organization: $(echo "$full_info" | grep -oP '"org":\s*"\K[^"]+')"
    fi
    echo ""
    
    # Check recent logs
    echo -e "${BLUE}${BOLD}Recent Activity (last 10 entries):${NC}"
    grep "$ip" /var/log/auth.log 2>/dev/null | tail -10 | while read line; do
        echo -e "  ${DIM}${line:0:100}${NC}"
    done
    
    # Check if IP is in fail2ban
    echo ""
    echo -e "${BLUE}${BOLD}Fail2ban Status:${NC}"
    if fail2ban-client status sshd 2>/dev/null | grep -q "$ip"; then
        echo -e "  ${RED}${WARNING} IP is banned in fail2ban${NC}"
    else
        echo -e "  ${GREEN}${CHECK} IP is not banned${NC}"
    fi
}

# Main display function
main_display() {
    clear
    
    # Header
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}            ACTIVE CONNECTIONS MONITOR                           ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}  $(date '+%Y-%m-%d %H:%M:%S')                                          ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    
    # Quick Stats
    total_conn=$(ss -tn | grep -v "State" | wc -l)
    established=$(ss -tn state established | wc -l)
    listen=$(ss -tln | wc -l)
    time_wait=$(ss -tn state time-wait | wc -l)
    
    echo ""
    echo -e "${GREEN}${BOLD}Total Connections: ${WHITE}${total_conn}${NC}  ${BLUE}|${NC}  ${GREEN}Established: ${WHITE}${established}${NC}  ${BLUE}|${NC}  ${GREEN}Listening: ${WHITE}${listen}${NC}  ${BLUE}|${NC}  ${GREEN}Time-Wait: ${WHITE}${time_wait}${NC}"
    
    # SSH Sessions
    print_section "CURRENT SSH SESSIONS"
    
    who_output=$(who)
    if [ -z "$who_output" ]; then
        echo -e "${DIM}  No active SSH sessions${NC}"
    else
        echo -e "${WHITE}${BOLD}  USER     TTY      FROM              LOGIN@   IDLE${NC}"
        echo -e "${DIM}  ─────────────────────────────────────────────────────────────${NC}"
        who -u | while read user tty date time idle pid from; do
            # Color code based on idle time
            if [[ "$idle" == "." ]] || [[ "$idle" == "00:00" ]]; then
                color="${GREEN}"  # Active
            else
                color="${YELLOW}"  # Idle
            fi
            printf "${color}  %-8s %-8s %-17s %s %s  %s${NC}\n" "$user" "$tty" "${from:-(local)}" "$date" "$time" "$idle"
        done
    fi
    
    # Connection Summary by Port
    print_section "CONNECTIONS BY PORT"
    
    echo -e "${WHITE}${BOLD}  PORT    SERVICE         CONN   STATE${NC}"
    echo -e "${DIM}  ────────────────────────────────────────${NC}"
    
    # Get unique ports and count connections
    ss -tn | grep -v "State" | awk '{print $4}' | sed 's/.*://' | sort | uniq -c | sort -rn | head -10 | while read count port; do
        # Get service name
        service=$(grep -E "^[a-zA-Z].*\s+$port/(tcp|udp)" /etc/services 2>/dev/null | head -1 | awk '{print $1}')
        [ -z "$service" ] && service="unknown"
        
        # Color based on count
        if [ $count -gt 50 ]; then
            color="${RED}"
            status="${WARNING}"
        elif [ $count -gt 20 ]; then
            color="${YELLOW}"
            status="${BULLET}"
        else
            color="${WHITE}"
            status=" "
        fi
        
        printf "${color}  %-7s %-15s %-6s${NC}\n" "$port" "$service" "$count"
    done
    
    # Established Connections with GeoIP
    print_section "ESTABLISHED CONNECTIONS"
    
    echo -e "${WHITE}${BOLD}  LOCAL ADDRESS         FOREIGN ADDRESS        STATE      LOCATION${NC}"
    echo -e "${DIM}  ──────────────────────────────────────────────────────────────────────${NC}"
    
    # Get established connections
    ss -tn state established | grep -v "State" | head -20 | while read state recv_q send_q local foreign; do
        # Extract IPs and ports
        local_addr=$local
        foreign_ip=$(echo $foreign | cut -d: -f1)
        foreign_port=$(echo $foreign | cut -d: -f2)
        
        # Get location
        location=$(get_ip_location "$foreign_ip")
        
        # Check if suspicious
        if check_suspicious_ip "$foreign_ip"; then
            color="${RED}"
            indicator="${WARNING}"
        elif [[ "$location" == *"China"* ]] || [[ "$location" == *"Russia"* ]]; then
            color="${YELLOW}"
            indicator="${BULLET}"
        else
            color="${WHITE}"
            indicator=" "
        fi
        
        printf "${color}%s %-21s %-22s %-10s %s${NC}\n" "$indicator" "$local_addr" "$foreign" "ESTAB" "$location"
    done
    
    # Listening Ports
    print_section "LISTENING PORTS"
    
    echo -e "${WHITE}${BOLD}  PORT    SERVICE         PROGRAM${NC}"
    echo -e "${DIM}  ────────────────────────────────────────${NC}"
    
    ss -tlnp | grep -v "State" | while read state recv_q send_q local foreign process; do
        port=$(echo $local | sed 's/.*://')
        
        # Skip IPv6 for clarity
        if [[ "$local" == *":::"* ]] || [[ "$local" == *"::"* ]]; then
            continue
        fi
        
        # Get service name
        service=$(grep -E "^[a-zA-Z].*\s+$port/(tcp|udp)" /etc/services 2>/dev/null | head -1 | awk '{print $1}')
        [ -z "$service" ] && service="custom"
        
        # Extract program name
        program=$(echo $process | grep -oP '"\K[^"]+' | head -1)
        [ -z "$program" ] && program="unknown"
        
        # Security check
        if [[ "$port" == "23" ]] || [[ "$port" == "135" ]] || [[ "$port" == "139" ]]; then
            color="${RED}"
            printf "${color}  %-7s %-15s %-20s ${WARNING} Risky port${NC}\n" "$port" "$service" "$program"
        else
            printf "${WHITE}  %-7s %-15s %-20s${NC}\n" "$port" "$service" "$program"
        fi
    done
    
    # Connection Statistics by Country
    print_section "CONNECTIONS BY COUNTRY"
    
    echo -e "${YELLOW}  Analyzing geographic distribution...${NC}"
    echo ""
    
    # Create temporary file for country stats
    temp_file="/tmp/conn_countries_$$"
    > "$temp_file"
    
    # Get all foreign IPs
    ss -tn state established | grep -v "State" | while read state recv_q send_q local foreign; do
        foreign_ip=$(echo $foreign | cut -d: -f1)
        if ! echo "$foreign_ip" | grep -qE "^(10\.|172\.|192\.168\.|127\.)"; then
            country=$(timeout 1 curl -s "http://ip-api.com/json/$foreign_ip" 2>/dev/null | grep -oP '"country":\s*"\K[^"]+' || echo "Unknown")
            echo "$country" >> "$temp_file"
        fi
    done
    
    # Count and display
    if [ -s "$temp_file" ]; then
        sort "$temp_file" | uniq -c | sort -rn | head -10 | while read count country; do
            # Create simple bar graph
            bar_length=$((count * 2))
            [ $bar_length -gt 40 ] && bar_length=40
            
            printf "  %-20s [" "$country"
            for i in $(seq 1 $bar_length); do
                if [ $count -gt 10 ]; then
                    printf "${RED}█${NC}"
                elif [ $count -gt 5 ]; then
                    printf "${YELLOW}█${NC}"
                else
                    printf "${GREEN}█${NC}"
                fi
            done
            printf "] ${WHITE}${count}${NC}\n"
        done
    else
        echo -e "${DIM}  No foreign connections${NC}"
    fi
    rm -f "$temp_file"
    
    # Recent Failed Connections
    print_section "RECENT CONNECTION ATTEMPTS (Failed SSH)"
    
    if [ -f /var/log/auth.log ]; then
        failed_attempts=$(grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5)
        if [ -n "$failed_attempts" ]; then
            echo "$failed_attempts" | while read line; do
                # Extract IP
                ip=$(echo "$line" | grep -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}")
                if [ -n "$ip" ]; then
                    location=$(get_ip_location "$ip")
                    timestamp=$(echo "$line" | awk '{print $1, $2, $3}')
                    echo -e "${RED}  ${timestamp} - ${ip} (${location})${NC}"
                fi
            done
        else
            echo -e "${GREEN}  ${CHECK} No recent failed attempts${NC}"
        fi
    fi
    
    # Security Summary
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}  SECURITY SUMMARY${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check for suspicious patterns
    suspicious_count=0
    
    # Check for too many connections from single IP
    ss -tn state established | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -1 | while read count ip; do
        if [ $count -gt 10 ]; then
            echo -e "${RED}  ${WARNING} High connection count from ${ip}: ${count} connections${NC}"
            suspicious_count=$((suspicious_count + 1))
        fi
    done
    
    # Check for unusual ports
    unusual_ports=$(ss -tln | awk '{print $4}' | sed 's/.*://' | grep -vE "^(22|80|443|3306|6379|5432)$" | head -5)
    if [ -n "$unusual_ports" ]; then
        echo -e "${YELLOW}  ${WARNING} Unusual listening ports detected: $(echo $unusual_ports | tr '\n' ' ')${NC}"
        suspicious_count=$((suspicious_count + 1))
    fi
    
    if [ $suspicious_count -eq 0 ]; then
        echo -e "${GREEN}  ${CHECK} No immediate security concerns detected${NC}"
    fi
}

# Interactive actions
show_actions() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}  AVAILABLE ACTIONS${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${YELLOW}K)${NC} Kill a connection"
    echo -e "  ${YELLOW}B)${NC} Block an IP address"
    echo -e "  ${YELLOW}D)${NC} Show detailed info for an IP"
    echo -e "  ${YELLOW}W)${NC} Watch specific IP/port"
    echo -e "  ${YELLOW}L)${NC} Show full netstat output"
    echo -e "  ${YELLOW}F)${NC} Show firewall rules"
    echo -e "  ${YELLOW}R)${NC} Refresh display"
    echo -e "  ${YELLOW}E)${NC} Export report"
    echo -e "  ${YELLOW}Q)${NC} Quit"
    echo ""
    echo -e "${DIM}────────────────────────────────────────────────────────────────────${NC}"
    echo ""
}

# Block IP function
block_ip() {
    local ip=$1
    
    echo -e "${YELLOW}Blocking IP: ${ip}${NC}"
    
    # Add to iptables
    iptables -I INPUT -s $ip -j DROP
    iptables -I OUTPUT -d $ip -j DROP
    
    # Add to fail2ban if available
    if command -v fail2ban-client &> /dev/null; then
        fail2ban-client set sshd banip $ip 2>/dev/null
    fi
    
    echo -e "${GREEN}${CHECK} IP ${ip} has been blocked${NC}"
    echo -e "${DIM}To unblock: iptables -D INPUT -s $ip -j DROP${NC}"
}

# Watch IP function
watch_ip() {
    local target=$1
    echo -e "${CYAN}Watching connections for: ${target}${NC}"
    echo -e "${DIM}Press Ctrl+C to stop${NC}"
    echo ""
    
    while true; do
        clear
        echo -e "${CYAN}Monitoring: ${target} - $(date '+%H:%M:%S')${NC}"
        echo ""
        ss -tn | grep "$target"
        sleep 2
    done
}

# Export report
export_report() {
    local filename="connections_report_$(date +%Y%m%d_%H%M%S).txt"
    echo "Generating report..."
    {
        echo "ACTIVE CONNECTIONS REPORT"
        echo "Generated: $(date)"
        echo "Host: $(hostname)"
        echo "================================"
        echo ""
        echo "SSH SESSIONS:"
        who -u
        echo ""
        echo "ESTABLISHED CONNECTIONS:"
        ss -tn state established
        echo ""
        echo "LISTENING PORTS:"
        ss -tln
        echo ""
        echo "CONNECTION STATISTICS:"
        ss -s
        echo ""
        echo "RECENT AUTH FAILURES:"
        grep "Failed password" /var/log/auth.log 2>/dev/null | tail -20
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
                echo ""
                ss -tn state established | grep -v "State" | head -10 | nl
                read -p "$(echo -e ${YELLOW}'Enter line number to kill: '${NC})" line_num
                if [[ "$line_num" =~ ^[0-9]+$ ]]; then
                    conn_info=$(ss -tn state established | grep -v "State" | sed -n "${line_num}p")
                    if [ -n "$conn_info" ]; then
                        foreign=$(echo "$conn_info" | awk '{print $5}')
                        foreign_ip=$(echo $foreign | cut -d: -f1)
                        foreign_port=$(echo $foreign | cut -d: -f2)
                        kill_connection "" "" "$foreign_ip" "$foreign_port"
                    fi
                fi
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                ;;
            b)
                read -p "$(echo -e ${YELLOW}'Enter IP to block: '${NC})" ip
                if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    block_ip "$ip"
                else
                    echo -e "${RED}Invalid IP address${NC}"
                fi
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                ;;
            d)
                read -p "$(echo -e ${YELLOW}'Enter IP for details: '${NC})" ip
                if [ -n "$ip" ]; then
                    show_connection_details "$ip"
                fi
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                ;;
            w)
                read -p "$(echo -e ${YELLOW}'Enter IP or port to watch: '${NC})" target
                if [ -n "$target" ]; then
                    watch_ip "$target"
                fi
                ;;
            l)
                echo ""
                echo -e "${CYAN}Full Network Statistics:${NC}"
                netstat -tunapl 2>/dev/null | head -50
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                ;;
            f)
                echo ""
                echo -e "${CYAN}Current Firewall Rules:${NC}"
                echo -e "${YELLOW}INPUT Chain:${NC}"
                iptables -L INPUT -n -v --line-numbers | head -20
                echo ""
                echo -e "${YELLOW}OUTPUT Chain:${NC}"
                iptables -L OUTPUT -n -v --line-numbers | head -10
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                ;;
            r)
                main_display
                ;;
            e)
                export_report
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

# Check for help
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Active Connections Monitor"
    echo "Usage: sudo $0 [options]"
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
    main
fi

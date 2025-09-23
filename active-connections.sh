#!/bin/bash
# Active Connections Monitor - Fixed Version
# Shows all network connections immediately with proper alignment
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
        echo "Local/Private"
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

# Function to block IP
block_ip() {
    local ip=$1
    
    echo ""
    echo -e "${YELLOW}Blocking IP: ${WHITE}${ip}${NC}"
    echo ""
    
    # Check which tools are available
    local blocked=0
    
    # Try fail2ban first (most common)
    if command -v fail2ban-client &> /dev/null; then
        # Get list of jails
        jails=$(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*:\s*//' | tr ',' ' ')
        
        if [ -n "$jails" ]; then
            for jail in $jails; do
                echo -e "${BLUE}Adding to fail2ban jail: ${jail}${NC}"
                fail2ban-client set $jail banip $ip 2>/dev/null && blocked=1
            done
        else
            echo -e "${YELLOW}No active fail2ban jails found${NC}"
        fi
    else
        echo -e "${YELLOW}Fail2ban not installed${NC}"
    fi
    
    # Try iptables if available
    if command -v iptables &> /dev/null; then
        echo -e "${BLUE}Adding iptables rule...${NC}"
        iptables -I INPUT -s $ip -j DROP 2>/dev/null && blocked=1
        iptables -I OUTPUT -d $ip -j DROP 2>/dev/null
    fi
    
    # Try ufw if available
    if command -v ufw &> /dev/null; then
        echo -e "${BLUE}Adding UFW rule...${NC}"
        ufw insert 1 deny from $ip 2>/dev/null && blocked=1
    fi
    
    if [ $blocked -eq 1 ]; then
        echo -e "${GREEN}${CHECK} IP ${ip} has been blocked${NC}"
        
        # Save to blocked IPs file for tracking
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $ip" >> /tmp/blocked_ips.log
    else
        echo -e "${RED}${CROSS} Failed to block IP (no firewall tools available)${NC}"
    fi
}

# Function to unblock IP
unblock_ip() {
    local ip=$1
    
    echo ""
    echo -e "${YELLOW}Unblocking IP: ${WHITE}${ip}${NC}"
    echo ""
    
    local unblocked=0
    
    # Try fail2ban
    if command -v fail2ban-client &> /dev/null; then
        jails=$(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*:\s*//' | tr ',' ' ')
        
        for jail in $jails; do
            echo -e "${BLUE}Removing from fail2ban jail: ${jail}${NC}"
            fail2ban-client set $jail unbanip $ip 2>/dev/null && unblocked=1
        done
    fi
    
    # Try iptables
    if command -v iptables &> /dev/null; then
        echo -e "${BLUE}Removing iptables rules...${NC}"
        iptables -D INPUT -s $ip -j DROP 2>/dev/null && unblocked=1
        iptables -D OUTPUT -d $ip -j DROP 2>/dev/null
    fi
    
    # Try ufw
    if command -v ufw &> /dev/null; then
        echo -e "${BLUE}Removing UFW rule...${NC}"
        ufw delete deny from $ip 2>/dev/null && unblocked=1
    fi
    
    if [ $unblocked -eq 1 ]; then
        echo -e "${GREEN}${CHECK} IP ${ip} has been unblocked${NC}"
    else
        echo -e "${YELLOW}IP may not have been blocked or already unblocked${NC}"
    fi
}

# Function to kill a connection
kill_connection() {
    local foreign_ip=$1
    local foreign_port=$2
    
    echo ""
    echo -e "${YELLOW}Attempting to kill connection to ${foreign_ip}:${foreign_port}...${NC}"
    
    # Use ss to kill the connection
    ss -K dst $foreign_ip dport = $foreign_port 2>/dev/null
    
    # Alternative: use tcpkill if available
    if command -v tcpkill &> /dev/null; then
        timeout 3 tcpkill -i any host $foreign_ip and port $foreign_port 2>/dev/null &
    fi
    
    echo -e "${GREEN}${CHECK} Connection kill signal sent${NC}"
    echo -e "${DIM}Note: Connection may take a moment to terminate${NC}"
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
    echo -e "${GREEN}${BOLD}Total: ${WHITE}${total_conn}${NC}  ${BLUE}|${NC}  ${GREEN}Established: ${WHITE}${established}${NC}  ${BLUE}|${NC}  ${GREEN}Listening: ${WHITE}${listen}${NC}  ${BLUE}|${NC}  ${GREEN}Time-Wait: ${WHITE}${time_wait}${NC}"
    
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
    
    # Full Network Statistics (netstat style)
    print_section "FULL NETWORK STATISTICS"
    
    echo -e "${WHITE}${BOLD}  Proto  Local Address          Foreign Address         State       PID/Program${NC}"
    echo -e "${DIM}  ──────────────────────────────────────────────────────────────────────────────${NC}"
    
    # Use ss with more details
    ss -tupn | grep -v "State" | head -30 | while IFS= read -r line; do
        # Parse the line
        proto=$(echo "$line" | awk '{print $1}')
        state=$(echo "$line" | awk '{print $2}')
        recv_q=$(echo "$line" | awk '{print $3}')
        send_q=$(echo "$line" | awk '{print $4}')
        local_addr=$(echo "$line" | awk '{print $5}')
        foreign_addr=$(echo "$line" | awk '{print $6}')
        process=$(echo "$line" | awk '{for(i=7;i<=NF;i++) printf "%s ", $i}')
        
        # Color based on state
        if [[ "$state" == "LISTEN" ]]; then
            color="${BLUE}"
        elif [[ "$state" == "ESTAB" ]]; then
            color="${GREEN}"
        elif [[ "$state" == "TIME-WAIT" ]]; then
            color="${YELLOW}"
        else
            color="${WHITE}"
        fi
        
        # Format and print
        printf "${color}  %-6s %-23s %-23s %-11s %s${NC}\n" \
            "$proto" "$local_addr" "$foreign_addr" "$state" "${process:0:20}"
    done
    
    # Show if there are more connections
    total_lines=$(ss -tupn | wc -l)
    if [ $total_lines -gt 30 ]; then
        echo -e "${DIM}  ... and $((total_lines - 30)) more connections${NC}"
    fi
    
    # Established Connections with GeoIP - FIXED ALIGNMENT
    print_section "ESTABLISHED CONNECTIONS WITH LOCATION"
    
    echo -e "${WHITE}${BOLD}  Local Address          Foreign Address         Location${NC}"
    echo -e "${DIM}  ────────────────────────────────────────────────────────────────${NC}"
    
    # Get established connections
    ss -tn state established | grep -v "State" | head -20 | while read state recv_q send_q local foreign; do
        # Skip if parsing failed
        [ -z "$foreign" ] && continue
        
        # Extract IP from foreign address
        foreign_ip=$(echo $foreign | cut -d: -f1)
        
        # Get location
        location=$(get_ip_location "$foreign_ip")
        
        # Check if suspicious
        if check_suspicious_ip "$foreign_ip"; then
            color="${RED}"
            indicator="${WARNING} "
        elif [[ "$location" == *"China"* ]] || [[ "$location" == *"Russia"* ]]; then
            color="${YELLOW}"
            indicator="${BULLET} "
        else
            color="${WHITE}"
            indicator="  "
        fi
        
        # Print with fixed width columns
        printf "${color}${indicator}%-22s %-23s %s${NC}\n" \
            "$local" "$foreign" "$location"
    done
    
    # Connection Summary by Port
    print_section "TOP CONNECTIONS BY PORT"
    
    echo -e "${WHITE}${BOLD}  Port    Service         Count${NC}"
    echo -e "${DIM}  ─────────────────────────────────${NC}"
    
    # Get unique ports and count connections
    ss -tn | grep -v "State" | awk '{print $4}' | sed 's/.*://' | sort | uniq -c | sort -rn | head -10 | while read count port; do
        # Get service name
        service=$(grep -E "^[a-zA-Z].*\s+$port/(tcp|udp)" /etc/services 2>/dev/null | head -1 | awk '{print $1}')
        [ -z "$service" ] && service="unknown"
        
        # Color based on count
        if [ $count -gt 50 ]; then
            color="${RED}"
        elif [ $count -gt 20 ]; then
            color="${YELLOW}"
        else
            color="${WHITE}"
        fi
        
        printf "${color}  %-7s %-15s %s${NC}\n" "$port" "$service" "$count"
    done
    
    # Listening Ports
    print_section "LISTENING PORTS"
    
    echo -e "${WHITE}${BOLD}  Port    Service         Program${NC}"
    echo -e "${DIM}  ─────────────────────────────────────${NC}"
    
    ss -tlnp | grep -v "State" | while read state recv_q send_q local foreign process; do
        port=$(echo $local | sed 's/.*://')
        
        # Skip IPv6 duplicates
        if [[ "$local" == *":::"* ]] || [[ "$local" == *"::"* ]]; then
            continue
        fi
        
        # Get service name
        service=$(grep -E "^[a-zA-Z].*\s+$port/(tcp|udp)" /etc/services 2>/dev/null | head -1 | awk '{print $1}')
        [ -z "$service" ] && service="custom"
        
        # Extract program name
        program=$(echo $process | grep -oP '"\K[^"]+' | head -1)
        [ -z "$program" ] && program="unknown"
        
        # Security check for risky ports
        if [[ "$port" == "23" ]] || [[ "$port" == "135" ]] || [[ "$port" == "139" ]]; then
            printf "${RED}  %-7s %-15s %-20s ${WARNING} Risky${NC}\n" "$port" "$service" "$program"
        else
            printf "${WHITE}  %-7s %-15s %s${NC}\n" "$port" "$service" "$program"
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
        [ -z "$foreign" ] && continue
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
            bar_length=$((count * 3))
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
    print_section "RECENT FAILED SSH ATTEMPTS"
    
    if [ -f /var/log/auth.log ]; then
        failed_attempts=$(grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5)
        if [ -n "$failed_attempts" ]; then
            echo "$failed_attempts" | while read line; do
                # Extract IP
                ip=$(echo "$line" | grep -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}")
                if [ -n "$ip" ]; then
                    location=$(get_ip_location "$ip")
                    timestamp=$(echo "$line" | awk '{print $1, $2, $3}')
                    printf "${RED}  %-20s %-18s %s${NC}\n" "$timestamp" "$ip" "($location)"
                fi
            done
        else
            echo -e "${GREEN}  ${CHECK} No recent failed attempts${NC}"
        fi
    fi
    
    # Currently Blocked IPs
    print_section "CURRENTLY BLOCKED IPS"
    
    blocked_count=0
    
    # Check fail2ban
    if command -v fail2ban-client &> /dev/null; then
        jails=$(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*:\s*//' | tr ',' ' ')
        
        for jail in $jails; do
            banned_ips=$(fail2ban-client status $jail 2>/dev/null | grep -A 100 "Banned IP list:" | grep -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}")
            if [ -n "$banned_ips" ]; then
                echo -e "${YELLOW}  Jail: ${jail}${NC}"
                echo "$banned_ips" | while read ip; do
                    location=$(get_ip_location "$ip")
                    printf "${RED}    %-18s %s${NC}\n" "$ip" "($location)"
                    blocked_count=$((blocked_count + 1))
                done
            fi
        done
    fi
    
    if [ $blocked_count -eq 0 ]; then
        echo -e "${DIM}  No IPs currently blocked${NC}"
    fi
    
    # Security Summary
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}  SECURITY SUMMARY${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check for suspicious patterns
    suspicious_found=0
    
    # Check for too many connections from single IP
    max_conn_ip=$(ss -tn state established | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -1)
    if [ -n "$max_conn_ip" ]; then
        count=$(echo "$max_conn_ip" | awk '{print $1}')
        ip=$(echo "$max_conn_ip" | awk '{print $2}')
        if [ $count -gt 10 ]; then
            echo -e "${RED}  ${WARNING} High connection count from ${ip}: ${count} connections${NC}"
            suspicious_found=1
        fi
    fi
    
    # Check for unusual ports
    unusual_ports=$(ss -tln | awk '{print $4}' | sed 's/.*://' | grep -vE "^(22|80|443|3306|6379|5432|25|53)$" | head -5)
    if [ -n "$unusual_ports" ]; then
        echo -e "${YELLOW}  ${WARNING} Unusual listening ports: $(echo $unusual_ports | tr '\n' ' ')${NC}"
        suspicious_found=1
    fi
    
    if [ $suspicious_found -eq 0 ]; then
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
    echo -e "  ${YELLOW}U)${NC} Unblock an IP address"
    echo -e "  ${YELLOW}R)${NC} Refresh display"
    echo -e "  ${YELLOW}E)${NC} Export report"
    echo -e "  ${YELLOW}Q)${NC} Quit"
    echo ""
    echo -e "${DIM}────────────────────────────────────────────────────────────────────${NC}"
    echo ""
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
        echo "NETWORK STATISTICS:"
        ss -tupn
        echo ""
        echo "ESTABLISHED CONNECTIONS:"
        ss -tn state established
        echo ""
        echo "LISTENING PORTS:"
        ss -tln
        echo ""
        echo "CONNECTION SUMMARY:"
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
                echo -e "${CYAN}Established connections:${NC}"
                ss -tn state established | grep -v "State" | head -10 | nl
                echo ""
                read -p "$(echo -e ${YELLOW}'Enter line number to kill: '${NC})" line_num
                if [[ "$line_num" =~ ^[0-9]+$ ]]; then
                    conn_info=$(ss -tn state established | grep -v "State" | sed -n "${line_num}p")
                    if [ -n "$conn_info" ]; then
                        foreign=$(echo "$conn_info" | awk '{print $5}')
                        foreign_ip=$(echo $foreign | cut -d: -f1)
                        foreign_port=$(echo $foreign | cut -d: -f2)
                        kill_connection "$foreign_ip" "$foreign_port"
                    fi
                fi
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                ;;
            b)
                read -p "$(echo -e ${YELLOW}'Enter IP to block: '${NC})" ip
                if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    block_ip "$ip"
                else
                    echo -e "${RED}Invalid IP address format${NC}"
                fi
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                ;;
            u)
                read -p "$(echo -e ${YELLOW}'Enter IP to unblock: '${NC})" ip
                if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    unblock_ip "$ip"
                else
                    echo -e "${RED}Invalid IP address format${NC}"
                fi
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

#!/bin/bash
# Fail2ban Advanced Monitor Script - All Errors Fixed
# Shows comprehensive fail2ban statistics and management
# Part of VPS Security Tools Suite
# Host as: fail2ban-monitor.sh

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo ""
    echo "⚠️  This script requires sudo privileges"
    echo "Please run: sudo $0"
    echo ""
    exit 1
fi

# Check if fail2ban is installed
if ! command -v fail2ban-client &> /dev/null; then
    echo ""
    echo "❌ Fail2ban is not installed"
    echo "Install with: sudo apt install fail2ban"
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

# Cache file for IP locations
CACHE_FILE="/tmp/fail2ban_ip_cache.txt"
CACHE_AGE=7 # days

# High-risk countries
HIGH_RISK="China|Russia|North Korea|Iran|DPR Korea|Korea, Democratic"
MEDIUM_RISK="Brazil|India|Vietnam|Ukraine|Romania|Nigeria|Turkey"

# Function to print section headers
print_section() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}${BOLD}  $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Function to get cached IP location
get_ip_location_cached() {
    local ip=$1
    
    # Check if IP is private
    if echo "$ip" | grep -qE "^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|::1|fe80:)"; then
        echo "Private/Local"
        return
    fi
    
    # Create cache file if doesn't exist
    [ ! -f "$CACHE_FILE" ] && touch "$CACHE_FILE"
    
    # Clean old cache entries (older than 7 days)
    if [ -f "$CACHE_FILE" ] && [ -s "$CACHE_FILE" ]; then
        temp_cache="/tmp/cache_temp_$$"
        current_time=$(date +%s)
        while IFS='|' read -r cached_ip cached_time cached_location; do
            if [ -n "$cached_ip" ] && [ -n "$cached_time" ]; then
                if [[ "$cached_time" =~ ^[0-9]+$ ]]; then
                    age=$(( (current_time - cached_time) / 86400 ))
                    if [ $age -lt $CACHE_AGE ]; then
                        echo "${cached_ip}|${cached_time}|${cached_location}" >> "$temp_cache"
                    fi
                fi
            fi
        done < "$CACHE_FILE" 2>/dev/null
        [ -f "$temp_cache" ] && mv "$temp_cache" "$CACHE_FILE"
    fi
    
    # Check cache first
    cached=$(grep "^${ip}|" "$CACHE_FILE" 2>/dev/null | tail -1)
    if [ -n "$cached" ]; then
        echo "$cached" | cut -d'|' -f3
        return
    fi
    
    # Not in cache, fetch location
    local location_data=$(timeout 2 curl -s "http://ip-api.com/json/$ip" 2>/dev/null)
    if [ -n "$location_data" ]; then
        local country=$(echo "$location_data" | grep -oP '"country":\s*"\K[^"]+' || echo "Unknown")
        local city=$(echo "$location_data" | grep -oP '"city":\s*"\K[^"]+' || echo "")
        
        if [ -n "$city" ] && [ "$city" != "null" ]; then
            location="$city, $country"
        else
            location="$country"
        fi
    else
        location="Unknown"
    fi
    
    # Save to cache
    echo "${ip}|$(date +%s)|${location}" >> "$CACHE_FILE"
    echo "$location"
}

# Function to calculate time remaining
calculate_remaining_time() {
    local jail=$1
    local ip=$2
    
    # Get ban time from jail configuration
    local bantime=$(fail2ban-client get $jail bantime 2>/dev/null | grep -oE '[0-9]+' | head -1)
    [ -z "$bantime" ] && bantime="600"
    
    # Try to find when IP was banned from log
    local ban_timestamp=$(grep "Ban $ip" /var/log/fail2ban.log 2>/dev/null | tail -1 | awk '{print $1, $2}')
    
    if [ -n "$ban_timestamp" ]; then
        local ban_epoch=$(date -d "$ban_timestamp" +%s 2>/dev/null || date +%s)
        local current_epoch=$(date +%s)
        local elapsed=$((current_epoch - ban_epoch))
        local remaining=$((bantime - elapsed))
        
        if [ $remaining -gt 0 ]; then
            if [ $remaining -gt 3600 ]; then
                echo "$((remaining / 3600))h $((remaining % 3600 / 60))m"
            else
                echo "$((remaining / 60))m"
            fi
        else
            echo "Expiring"
        fi
    else
        echo "${bantime}s"
    fi
}

# Function to get jail efficiency
calculate_efficiency() {
    local failed=$1
    local banned=$2
    
    # Ensure we have numbers
    failed=${failed:-0}
    banned=${banned:-0}
    
    if [ "$failed" -eq 0 ]; then
        echo "N/A"
    else
        local efficiency=$(echo "scale=1; $banned * 100 / $failed" | bc 2>/dev/null || echo "0")
        echo "${efficiency}%"
    fi
}

# Function to ban an IP
ban_ip() {
    local ip=$1
    local jail=${2:-sshd}
    
    echo -e "${YELLOW}Banning IP ${ip} in jail ${jail}...${NC}"
    
    if fail2ban-client set $jail banip $ip 2>/dev/null; then
        echo -e "${GREEN}${CHECK} Successfully banned ${ip}${NC}"
    else
        echo -e "${RED}${CROSS} Failed to ban ${ip}${NC}"
    fi
}

# Function to unban an IP
unban_ip() {
    local ip=$1
    local jail=${2:-"all"}
    
    echo -e "${YELLOW}Unbanning IP ${ip}...${NC}"
    
    if [ "$jail" = "all" ]; then
        # Unban from all jails
        local jails=$(fail2ban-client status | grep "Jail list" | sed 's/.*:\s*//' | tr ',' ' ')
        for j in $jails; do
            fail2ban-client set $j unbanip $ip 2>/dev/null && \
                echo -e "${GREEN}  Unbanned from ${j}${NC}"
        done
    else
        if fail2ban-client set $jail unbanip $ip 2>/dev/null; then
            echo -e "${GREEN}${CHECK} Successfully unbanned ${ip} from ${jail}${NC}"
        else
            echo -e "${RED}${CROSS} Failed to unban ${ip}${NC}"
        fi
    fi
}

# Main display function
main_display() {
    clear
    
    # Header
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}           FAIL2BAN ADVANCED MONITOR                             ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${WHITE}  $(date '+%Y-%m-%d %H:%M:%S')                                          ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    
    # System Status
    print_section "SYSTEM STATUS"
    
    # Check if fail2ban is running
    if systemctl is-active --quiet fail2ban; then
        status="${GREEN}Active ${CHECK}${NC}"
        
        # Get version
        version=$(fail2ban-client version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        [ -z "$version" ] && version="Unknown"
        
        # Get uptime
        uptime=$(systemctl show fail2ban --property=ActiveEnterTimestamp --value)
        if [ -n "$uptime" ]; then
            uptime_seconds=$(( $(date +%s) - $(date -d "$uptime" +%s) ))
            uptime_days=$((uptime_seconds / 86400))
            uptime_hours=$(( (uptime_seconds % 86400) / 3600 ))
            uptime_str="${uptime_days}d ${uptime_hours}h"
        else
            uptime_str="Unknown"
        fi
    else
        status="${RED}Inactive ${CROSS}${NC}"
        echo -e "${RED}${BOLD}Fail2ban is not running!${NC}"
        echo -e "${YELLOW}Start with: sudo systemctl start fail2ban${NC}"
        return
    fi
    
    # Get jail count
    jail_list=$(fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*:\s*//')
    if [ -n "$jail_list" ]; then
        total_jails=$(echo "$jail_list" | tr ',' '\n' | grep -v "^$" | wc -l)
    else
        total_jails=0
    fi
    
    echo -e "${BLUE}  Status:${NC} $status"
    echo -e "${BLUE}  Version:${NC} ${WHITE}${version}${NC}"
    echo -e "${BLUE}  Uptime:${NC} ${WHITE}${uptime_str}${NC}"
    echo -e "${BLUE}  Total Jails:${NC} ${WHITE}${total_jails}${NC}"
    
    # Jail Statistics Table
    print_section "JAIL STATISTICS"
    
    # Table header
    printf "${WHITE}${BOLD}"
    printf "  %-15s %-8s %-10s %-10s %-10s %-12s\n" "Jail" "Status" "Failed" "Banned" "Current" "Efficiency"
    printf "${DIM}  ─────────────────────────────────────────────────────────────────────────\n${NC}"
    
    # Process each jail
    total_failed=0
    total_banned=0
    total_current=0
    
    if [ -n "$jail_list" ]; then
        echo "$jail_list" | tr ',' '\n' | grep -v "^$" | while read jail; do
            jail=$(echo $jail | xargs) # trim whitespace
            if [ -n "$jail" ]; then
                # Get jail status
                jail_status=$(fail2ban-client status "$jail" 2>/dev/null)
                
                if [ -n "$jail_status" ]; then
                    failed=$(echo "$jail_status" | grep "Total failed:" | awk '{print $NF}' | head -1)
                    banned=$(echo "$jail_status" | grep "Total banned:" | awk '{print $NF}' | head -1)
                    current=$(echo "$jail_status" | grep "Currently banned:" | awk '{print $NF}' | head -1)
                    
                    # Ensure we have numbers
                    failed=${failed:-0}
                    banned=${banned:-0}
                    current=${current:-0}
                    
                    # Calculate efficiency
                    efficiency=$(calculate_efficiency "$failed" "$banned")
                    
                    # Color based on activity
                    if [ "$current" -gt 0 ]; then
                        color="${YELLOW}"
                        status_text="${GREEN}ACTIVE${NC}"
                    else
                        color="${WHITE}"
                        status_text="${GREEN}ACTIVE${NC}"
                    fi
                    
                    # Highlight if efficiency is concerning
                    if [ "$failed" -gt 100 ] && [ "$banned" -eq 0 ]; then
                        efficiency="${RED}0% ${WARNING}${NC}"
                    fi
                    
                    printf "${color}  %-15s ${status_text} %-10s %-10s %-10s %-12s${NC}\n" \
                        "$jail" "$failed" "$banned" "$current" "$efficiency"
                    
                    # Update totals - store in temp file to persist across subshell
                    echo "$failed $banned $current" >> /tmp/jail_totals_$$
                fi
            fi
        done
        
        # Calculate totals from temp file
        if [ -f /tmp/jail_totals_$$ ]; then
            while read f b c; do
                total_failed=$((total_failed + f))
                total_banned=$((total_banned + b))
                total_current=$((total_current + c))
            done < /tmp/jail_totals_$$
            rm -f /tmp/jail_totals_$$
        fi
    fi
    
    # Total row
    printf "${DIM}  ─────────────────────────────────────────────────────────────────────────\n${NC}"
    total_efficiency=$(calculate_efficiency "$total_failed" "$total_banned")
    printf "${WHITE}${BOLD}  %-15s %-8s %-10s %-10s %-10s %-12s${NC}\n" \
        "TOTAL" "" "$total_failed" "$total_banned" "$total_current" "$total_efficiency"
    
    # Currently Banned IPs (Table format)
    print_section "CURRENTLY BANNED IPS (Latest 15)"
    
    if [ "$total_current" -gt 0 ]; then
        # Table header
        printf "${WHITE}${BOLD}"
        printf "  %-18s %-22s %-10s %-12s %-10s\n" "IP Address" "Location" "Jail" "Ban Time" "Remaining"
        printf "${DIM}  ─────────────────────────────────────────────────────────────────────────\n${NC}"
        
        # Collect all banned IPs with details
        temp_file="/tmp/banned_ips_$$"
        > "$temp_file"
        
        echo "$jail_list" | tr ',' '\n' | grep -v "^$" | while read jail; do
            jail=$(echo $jail | xargs)
            if [ -n "$jail" ]; then
                # Get banned IPs for this jail
                banned_ips=$(fail2ban-client status "$jail" 2>/dev/null | grep -A 100 "Banned IP list:" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
                
                for ip in $banned_ips; do
                    # Get ban timestamp from log
                    ban_time=$(grep "Ban $ip" /var/log/fail2ban.log 2>/dev/null | tail -1 | awk '{print $2}' | cut -d',' -f1)
                    [ -z "$ban_time" ] && ban_time="Unknown"
                    
                    echo "${ip}|${jail}|${ban_time}" >> "$temp_file"
                done
            fi
        done
        
        # Sort by time and show latest 15
        if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
            sort -t'|' -k3 -r "$temp_file" 2>/dev/null | head -15 | while IFS='|' read -r ip jail ban_time; do
                if [ -n "$ip" ]; then
                    # Get location (cached)
                    location=$(get_ip_location_cached "$ip")
                    
                    # Calculate remaining time
                    remaining=$(calculate_remaining_time "$jail" "$ip")
                    
                    # Color based on location risk
                    if echo "$location" | grep -qE "$HIGH_RISK"; then
                        loc_color="${RED}"
                    elif echo "$location" | grep -qE "$MEDIUM_RISK"; then
                        loc_color="${YELLOW}"
                    else
                        loc_color="${WHITE}"
                    fi
                    
                    printf "  %-18s ${loc_color}%-22s${NC} %-10s %-12s %-10s\n" \
                        "$ip" "${location:0:22}" "$jail" "$ban_time" "$remaining"
                fi
            done
        fi
        
        rm -f "$temp_file"
        
        if [ "$total_current" -gt 15 ]; then
            echo ""
            echo -e "${DIM}  ... and $((total_current - 15)) more banned IPs${NC}"
        fi
    else
        echo -e "${DIM}  No IPs currently banned${NC}"
    fi
    
    # Attack Trends (7 days)
    print_section "ATTACK TRENDS (7 days)"
    
    if [ -f /var/log/fail2ban.log ]; then
        echo -e "${BLUE}  Daily Ban Count:${NC}"
        echo ""
        
        for i in {6..0}; do
            date=$(date -d "$i days ago" '+%Y-%m-%d')
            day_name=$(date -d "$i days ago" '+%a')
            
            # Count bans for this day
            count=$(grep "$date" /var/log/fail2ban.log 2>/dev/null | grep -c "Ban")
            
            # Ensure count is a valid number
            if ! [[ "$count" =~ ^[0-9]+$ ]]; then
                count=0
            fi
            
            # Create bar
            printf "  %s %s [" "$day_name" "$date"
            
            if [ "$count" -gt 0 ]; then
                bar_length=$((count / 2))
                [ $bar_length -eq 0 ] && bar_length=1
                [ $bar_length -gt 30 ] && bar_length=30
                
                for j in $(seq 1 $bar_length); do
                    if [ $count -gt 50 ]; then
                        printf "${RED}█${NC}"
                    elif [ $count -gt 20 ]; then
                        printf "${YELLOW}█${NC}"
                    else
                        printf "${GREEN}█${NC}"
                    fi
                done
            fi
            
            printf "] ${WHITE}%d${NC}\n" "$count"
        done
    else
        echo -e "${DIM}  No fail2ban log found${NC}"
    fi
    
    # Top Attacking Countries
    print_section "TOP ATTACKING COUNTRIES"
    
    echo -e "${YELLOW}  Analyzing geographic distribution...${NC}"
    echo ""
    
    # Collect all banned IPs from all jails
    country_file="/tmp/countries_$$"
    > "$country_file"
    
    if [ -n "$jail_list" ]; then
        echo "$jail_list" | tr ',' '\n' | grep -v "^$" | while read jail; do
            jail=$(echo $jail | xargs)
            if [ -n "$jail" ]; then
                banned_ips=$(fail2ban-client status "$jail" 2>/dev/null | grep -A 100 "Banned IP list:" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
                for ip in $banned_ips; do
                    location=$(get_ip_location_cached "$ip")
                    # Extract country from location
                    country=$(echo "$location" | sed 's/.*,\s*//' | sed 's/^\s*//')
                    [ "$country" = "Unknown" ] || [ "$country" = "Private/Local" ] || echo "$country" >> "$country_file"
                done
            fi
        done
    fi
    
    if [ -s "$country_file" ]; then
        sort "$country_file" | uniq -c | sort -rn | head -10 | while read count country; do
            # Ensure count is a number
            if ! [[ "$count" =~ ^[0-9]+$ ]]; then
                continue
            fi
            
            # Color based on risk
            if echo "$country" | grep -qE "$HIGH_RISK"; then
                color="${RED}"
            elif echo "$country" | grep -qE "$MEDIUM_RISK"; then
                color="${YELLOW}"
            else
                color="${WHITE}"
            fi
            
            # Create bar
            printf "${color}  %-20s${NC} [" "$country"
            
            if [ $count -gt 0 ]; then
                bar_length=$((count * 2))
                [ $bar_length -eq 0 ] && bar_length=1
                [ $bar_length -gt 30 ] && bar_length=30
                
                for i in $(seq 1 $bar_length); do
                    printf "${color}█${NC}"
                done
            fi
            
            printf "] ${WHITE}%d bans${NC}\n" "$count"
        done
    else
        echo -e "${DIM}  No country data available${NC}"
    fi
    rm -f "$country_file"
    
    # Enhanced Statistics
    print_section "ENHANCED STATISTICS"
    
    # Calculate statistics from logs
    if [ -f /var/log/fail2ban.log ]; then
        # Peak attack hour (last 24h)
        peak_hour=$(grep "$(date '+%Y-%m-%d')" /var/log/fail2ban.log 2>/dev/null | grep "Ban" | awk '{print $2}' | cut -d':' -f1 | sort | uniq -c | sort -rn | head -1)
        if [ -n "$peak_hour" ]; then
            hour_count=$(echo "$peak_hour" | awk '{print $1}')
            hour_time=$(echo "$peak_hour" | awk '{print $2}')
            if [ -n "$hour_count" ] && [ -n "$hour_time" ]; then
                echo -e "${BLUE}  ${BULLET} Peak Attack Hour:${NC} ${WHITE}${hour_time}:00-${hour_time}:59 UTC (${hour_count} bans)${NC}"
            fi
        fi
        
        # Repeat offenders (last 7 days)
        repeat_file="/tmp/repeats_$$"
        grep "Ban" /var/log/fail2ban.log 2>/dev/null | tail -1000 | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | \
            sort | uniq -c | sort -rn | awk '$1>1' > "$repeat_file"
        repeat_count=$(wc -l < "$repeat_file" 2>/dev/null)
        repeat_count=${repeat_count:-0}
        
        if [ "$repeat_count" -gt 0 ]; then
            top_repeat=$(head -1 "$repeat_file")
            if [ -n "$top_repeat" ]; then
                repeat_ip=$(echo "$top_repeat" | awk '{print $2}')
                repeat_times=$(echo "$top_repeat" | awk '{print $1}')
                echo -e "${BLUE}  ${BULLET} Repeat Offenders:${NC} ${WHITE}${repeat_count} IPs${NC} ${DIM}(Top: ${repeat_ip} - ${repeat_times} times)${NC}"
            fi
        fi
        rm -f "$repeat_file"
        
        # Most targeted port
        if [ -f /var/log/auth.log ]; then
            top_port=$(grep "port" /var/log/auth.log 2>/dev/null | tail -1000 | grep -oE 'port [0-9]+' | sort | uniq -c | sort -rn | head -1)
            if [ -n "$top_port" ]; then
                port_count=$(echo "$top_port" | awk '{print $1}')
                port_num=$(echo "$top_port" | awk '{print $3}')
                if [ -n "$port_count" ] && [ -n "$port_num" ]; then
                    echo -e "${BLUE}  ${BULLET} Most Targeted Port:${NC} ${WHITE}${port_num} (${port_count} attempts)${NC}"
                fi
            fi
        fi
        
        # Average ban duration
        echo -e "${BLUE}  ${BULLET} Default Ban Duration:${NC} ${WHITE}10 minutes${NC} ${DIM}(configurable per jail)${NC}"
        
        # Total IPs blocked all-time
        total_all_time=$(grep -c "Ban" /var/log/fail2ban.log 2>/dev/null)
        total_all_time=${total_all_time:-0}
        echo -e "${BLUE}  ${BULLET} Total Bans (all-time):${NC} ${WHITE}${total_all_time}${NC}"
    fi
    
    # Bans in last hour
    last_hour_bans=$(grep "$(date '+%Y-%m-%d %H')" /var/log/fail2ban.log 2>/dev/null | grep -c "Ban")
    # Ensure it's a number
    if ! [[ "$last_hour_bans" =~ ^[0-9]+$ ]]; then
        last_hour_bans=0
    fi
    echo -e "${BLUE}  ${BULLET} Bans in Last Hour:${NC} ${WHITE}${last_hour_bans}${NC}"
    
    # Security Alerts
    print_section "SECURITY ALERTS"
    
    alerts=0
    
    # Check ban rate - ensure we have a number
    if [[ "$last_hour_bans" =~ ^[0-9]+$ ]]; then
        if [ "$last_hour_bans" -gt 100 ]; then
            echo -e "${BG_RED}${WHITE}${BOLD}  ${WARNING} DDoS ALERT: ${last_hour_bans} bans in last hour! ${NC}"
            alerts=$((alerts + 1))
        elif [ "$last_hour_bans" -gt 50 ]; then
            echo -e "${RED}  ${WARNING} Critical: High attack rate (${last_hour_bans} bans/hour)${NC}"
            alerts=$((alerts + 1))
        elif [ "$last_hour_bans" -gt 20 ]; then
            echo -e "${YELLOW}  ${WARNING} Warning: Elevated attack rate (${last_hour_bans} bans/hour)${NC}"
            alerts=$((alerts + 1))
        fi
    fi
    
    # Check for jails with 0% efficiency
    if [ -n "$jail_list" ]; then
        echo "$jail_list" | tr ',' '\n' | grep -v "^$" | while read jail; do
            jail=$(echo $jail | xargs)
            if [ -n "$jail" ]; then
                jail_status=$(fail2ban-client status "$jail" 2>/dev/null)
                failed=$(echo "$jail_status" | grep "Total failed:" | awk '{print $NF}' | head -1)
                banned=$(echo "$jail_status" | grep "Total banned:" | awk '{print $NF}' | head -1)
                
                failed=${failed:-0}
                banned=${banned:-0}
                
                if [[ "$failed" =~ ^[0-9]+$ ]] && [[ "$banned" =~ ^[0-9]+$ ]]; then
                    if [ "$failed" -gt 100 ] && [ "$banned" -eq 0 ]; then
                        echo -e "${YELLOW}  ${WARNING} Jail '${jail}' may be misconfigured (0% efficiency)${NC}"
                        alerts=$((alerts + 1))
                    fi
                fi
            fi
        done
    fi
    
    if [ $alerts -eq 0 ]; then
        echo -e "${GREEN}  ${CHECK} All systems normal${NC}"
    fi
}

# Show actions menu
show_actions() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${BOLD}  AVAILABLE ACTIONS${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${YELLOW}B)${NC} Ban an IP manually"
    echo -e "  ${YELLOW}U)${NC} Unban an IP"
    echo -e "  ${YELLOW}D)${NC} Detailed IP intelligence"
    echo -e "  ${YELLOW}H)${NC} Historical analysis (30 days)"
    echo -e "  ${YELLOW}W)${NC} Whitelist management"
    echo -e "  ${YELLOW}J)${NC} Jail configuration"
    echo -e "  ${YELLOW}A)${NC} Show all banned IPs"
    echo -e "  ${YELLOW}R)${NC} Refresh display"
    echo -e "  ${YELLOW}E)${NC} Export banned IPs list"
    echo -e "  ${YELLOW}Q)${NC} Quit"
    echo ""
    echo -e "${DIM}────────────────────────────────────────────────────────────────────${NC}"
    echo ""
}

# Historical analysis - FIXED
show_historical_analysis() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}  HISTORICAL ANALYSIS (30 days)${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ ! -f /var/log/fail2ban.log ]; then
        echo -e "${RED}No fail2ban log found${NC}"
        return
    fi
    
    echo -e "${BLUE}${BOLD}Daily Ban Statistics:${NC}"
    echo ""
    
    for i in {29..0}; do
        date=$(date -d "$i days ago" '+%Y-%m-%d')
        day_name=$(date -d "$i days ago" '+%a')
        count=$(grep "$date" /var/log/fail2ban.log 2>/dev/null | grep -c "Ban")
        
        # Ensure count is a number
        if ! [[ "$count" =~ ^[0-9]+$ ]]; then
            count=0
        fi
        
        # Only show days with activity
        if [ "$count" -gt 0 ]; then
            printf "  %s %s: %3d bans\n" "$day_name" "$date" "$count"
        fi
    done
    
    echo ""
    echo -e "${BLUE}${BOLD}Top 10 Banned IPs (30 days):${NC}"
    echo ""
    
    grep "Ban" /var/log/fail2ban.log 2>/dev/null | \
        grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | \
        sort | uniq -c | sort -rn | head -10 | while read count ip; do
        if [ -n "$ip" ]; then
            location=$(get_ip_location_cached "$ip")
            printf "  %-18s %4d bans  (%s)\n" "$ip" "$count" "$location"
        fi
    done
}

# IP Intelligence function
show_ip_intelligence() {
    local ip=$1
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}  IP Intelligence Report: ${ip}${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Get full data from IP API
    echo -e "${YELLOW}Fetching detailed information...${NC}"
    echo ""
    
    data=$(curl -s "http://ip-api.com/json/$ip?fields=status,message,continent,country,countryCode,region,regionName,city,zip,lat,lon,timezone,isp,org,as,asname,reverse,mobile,proxy,hosting" 2>/dev/null)
    
    if [ -n "$data" ]; then
        echo -e "${BLUE}${BOLD}Geographic Information:${NC}"
        echo "  Country: $(echo "$data" | grep -oP '"country":\s*"\K[^"]+')"
        echo "  Region: $(echo "$data" | grep -oP '"regionName":\s*"\K[^"]+')"
        echo "  City: $(echo "$data" | grep -oP '"city":\s*"\K[^"]+')"
        echo "  Timezone: $(echo "$data" | grep -oP '"timezone":\s*"\K[^"]+')"
        echo "  Coordinates: $(echo "$data" | grep -oP '"lat":\s*\K[^,]+'), $(echo "$data" | grep -oP '"lon":\s*\K[^,]+')"
        echo ""
        
        echo -e "${BLUE}${BOLD}Network Information:${NC}"
        echo "  ISP: $(echo "$data" | grep -oP '"isp":\s*"\K[^"]+')"
        echo "  Organization: $(echo "$data" | grep -oP '"org":\s*"\K[^"]+')"
        echo "  AS Number: $(echo "$data" | grep -oP '"as":\s*"\K[^"]+')"
        echo "  Reverse DNS: $(echo "$data" | grep -oP '"reverse":\s*"\K[^"]+')"
        echo ""
        
        echo -e "${BLUE}${BOLD}Risk Indicators:${NC}"
        proxy=$(echo "$data" | grep -oP '"proxy":\s*\K[^,]+')
        hosting=$(echo "$data" | grep -oP '"hosting":\s*\K[^,]+')
        
        [ "$proxy" = "true" ] && echo -e "  ${RED}${WARNING} Proxy/VPN detected${NC}" || echo -e "  ${GREEN}${CHECK} Not a known proxy${NC}"
        [ "$hosting" = "true" ] && echo -e "  ${YELLOW}${WARNING} Hosting/Datacenter IP${NC}" || echo -e "  ${GREEN}${CHECK} Not a datacenter${NC}"
    fi
    
    # Check in fail2ban logs
    echo ""
    echo -e "${BLUE}${BOLD}Fail2ban History:${NC}"
    
    if [ -f /var/log/fail2ban.log ]; then
        ban_count=$(grep -c "Ban $ip" /var/log/fail2ban.log 2>/dev/null)
        ban_count=${ban_count:-0}
        echo "  Total bans: $ban_count"
        
        if [ $ban_count -gt 0 ]; then
            echo "  First seen: $(grep "Ban $ip" /var/log/fail2ban.log | head -1 | awk '{print $1, $2}')"
            echo "  Last seen: $(grep "Ban $ip" /var/log/fail2ban.log | tail -1 | awk '{print $1, $2}')"
            
            # Show which jails banned this IP
            echo "  Banned by jails:"
            grep "Ban $ip" /var/log/fail2ban.log | grep -oE '\[[^]]+\]' | sort -u | while read jail; do
                echo "    - $jail"
            done
        fi
    fi
    
    # Check auth logs for attempts
    if [ -f /var/log/auth.log ]; then
        echo ""
        echo -e "${BLUE}${BOLD}Recent Attack Attempts:${NC}"
        grep "$ip" /var/log/auth.log 2>/dev/null | tail -5 | while read line; do
            echo "  ${line:0:80}"
        done
    fi
}

# Whitelist management
manage_whitelist() {
    local whitelist_file="/etc/fail2ban/jail.local"
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}  WHITELIST MANAGEMENT${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${BLUE}${BOLD}Current Whitelist:${NC}"
    
    if [ -f "$whitelist_file" ]; then
        ignoreip=$(grep "^ignoreip" "$whitelist_file" 2>/dev/null | sed 's/ignoreip\s*=\s*//')
        if [ -n "$ignoreip" ]; then
            echo "$ignoreip" | tr ' ' '\n' | while read ip; do
                [ -n "$ip" ] && echo "  ${GREEN}${CHECK}${NC} $ip"
            done
        else
            echo -e "${DIM}  No IPs whitelisted${NC}"
        fi
    else
        echo -e "${DIM}  No whitelist configured${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo "  1) Add IP to whitelist"
    echo "  2) Remove IP from whitelist"
    echo "  3) Return to main menu"
    echo ""
    
    read -p "$(echo -e ${YELLOW}'Select option: '${NC})" opt
    
    case $opt in
        1)
            read -p "$(echo -e ${YELLOW}'Enter IP to whitelist: '${NC})" new_ip
            if [[ "$new_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                echo -e "${YELLOW}Adding $new_ip to whitelist...${NC}"
                echo -e "${DIM}Note: Manual edit of /etc/fail2ban/jail.local required${NC}"
                echo -e "${DIM}Add to ignoreip line and restart fail2ban${NC}"
            else
                echo -e "${RED}Invalid IP format${NC}"
            fi
            ;;
        2)
            read -p "$(echo -e ${YELLOW}'Enter IP to remove: '${NC})" rem_ip
            echo -e "${YELLOW}Removing $rem_ip from whitelist...${NC}"
            echo -e "${DIM}Note: Manual edit of /etc/fail2ban/jail.local required${NC}"
            ;;
    esac
}

# Show all banned IPs
show_all_banned() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}${BOLD}  ALL CURRENTLY BANNED IPS${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    jail_list=$(fail2ban-client status | grep "Jail list" | sed 's/.*:\s*//')
    
    if [ -n "$jail_list" ]; then
        echo "$jail_list" | tr ',' '\n' | grep -v "^$" | while read jail; do
            jail=$(echo $jail | xargs)
            if [ -n "$jail" ]; then
                banned_ips=$(fail2ban-client status "$jail" 2>/dev/null | grep -A 1000 "Banned IP list:" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
                
                if [ -n "$banned_ips" ]; then
                    echo -e "${YELLOW}${BOLD}Jail: $jail${NC}"
                    echo "$banned_ips" | while read ip; do
                        location=$(get_ip_location_cached "$ip")
                        printf "  %-18s %s\n" "$ip" "($location)"
                    done
                    echo ""
                fi
            fi
        done
    fi
}

# Export banned IPs
export_banned_ips() {
    local filename="banned_ips_$(date +%Y%m%d_%H%M%S).txt"
    
    echo "Exporting banned IPs to $filename..."
    
    {
        echo "# Fail2ban Banned IPs Export"
        echo "# Generated: $(date)"
        echo "# Host: $(hostname)"
        echo ""
        
        jail_list=$(fail2ban-client status | grep "Jail list" | sed 's/.*:\s*//')
        
        if [ -n "$jail_list" ]; then
            echo "$jail_list" | tr ',' '\n' | grep -v "^$" | while read jail; do
                jail=$(echo $jail | xargs)
                if [ -n "$jail" ]; then
                    echo "# Jail: $jail"
                    fail2ban-client status "$jail" 2>/dev/null | \
                        grep -A 1000 "Banned IP list:" | \
                        grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'
                    echo ""
                fi
            done
        fi
    } > "$filename"
    
    echo -e "${GREEN}${CHECK} Exported to: $filename${NC}"
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
            b)
                read -p "$(echo -e ${YELLOW}'Enter IP to ban: '${NC})" ip
                if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    read -p "$(echo -e ${YELLOW}'Enter jail name (default: sshd): '${NC})" jail
                    [ -z "$jail" ] && jail="sshd"
                    ban_ip "$ip" "$jail"
                else
                    echo -e "${RED}Invalid IP format${NC}"
                fi
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                ;;
            u)
                read -p "$(echo -e ${YELLOW}'Enter IP to unban: '${NC})" ip
                if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    read -p "$(echo -e ${YELLOW}'Enter jail name (or "all" for all jails): '${NC})" jail
                    [ -z "$jail" ] && jail="all"
                    unban_ip "$ip" "$jail"
                else
                    echo -e "${RED}Invalid IP format${NC}"
                fi
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                ;;
            d)
                read -p "$(echo -e ${YELLOW}'Enter IP for intelligence report: '${NC})" ip
                if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    show_ip_intelligence "$ip"
                else
                    echo -e "${RED}Invalid IP format${NC}"
                fi
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                ;;
            h)
                show_historical_analysis
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                ;;
            w)
                manage_whitelist
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                ;;
            j)
                echo ""
                echo -e "${CYAN}Jail Configuration:${NC}"
                fail2ban-client status
                echo ""
                read -p "$(echo -e ${YELLOW}'Enter jail name for details: '${NC})" jail
                if [ -n "$jail" ]; then
                    echo ""
                    fail2ban-client get "$jail" bantime 2>/dev/null && echo ""
                    fail2ban-client get "$jail" findtime 2>/dev/null && echo ""
                    fail2ban-client get "$jail" maxretry 2>/dev/null
                fi
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                ;;
            a)
                show_all_banned
                read -p "$(echo -e ${DIM}'Press Enter to continue...'${NC})"
                ;;
            r)
                main_display
                ;;
            e)
                export_banned_ips
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
    echo "Fail2ban Advanced Monitor"
    echo "Usage: sudo $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -w, --watch    Auto-refresh every 10 seconds"
    echo ""
    exit 0
fi

# Check for watch mode
if [[ "$1" == "-w" ]] || [[ "$1" == "--watch" ]]; then
    while true; do
        main_display
        echo ""
        echo -e "${DIM}Auto-refresh in 10 seconds... Press Ctrl+C to stop${NC}"
        sleep 10
    done
else
    main
fi

#!/bin/bash
# VPS Security Check with Internet Search
# Part of VPS Tools Suite
# Host as: security-check.sh

# Colors - Enhanced for better visibility
RED='\033[1;31m'      # Bold Red
GREEN='\033[1;32m'    # Bold Green
YELLOW='\033[1;33m'   # Bold Yellow
BLUE='\033[1;34m'     # Bold Blue
CYAN='\033[1;36m'     # Bold Cyan
MAGENTA='\033[1;35m'  # Bold Magenta
BOLD='\033[1m'        # Bold
DIM='\033[2m'         # Dim
NC='\033[0m'          # No Color

# Helper function for beginners
wait_for_enter() {
    echo ""
    echo -e "${YELLOW}${BOLD}Press Enter to continue...${NC}"
    read
}

# Safe error handling for beginners
safe_command() {
    local cmd="$1"
    local description="$2"
    
    echo -e "${DIM}Running: $description${NC}"
    if ! eval "$cmd" 2>/dev/null; then
        echo -e "${YELLOW}ℹ️  $description: Data not available or permission denied${NC}"
        return 1
    fi
    return 0
}

# Function to search for process/service information
search_process_info() {
    local query="$1"
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}🔍  SEARCHING FOR: ${YELLOW}$query${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
    echo ""
    
    # Clean the query - remove .service suffix if present
    clean_query=$(echo "$query" | sed 's/\.service$//')
    
    # Method 1: Local Security Database Check
    echo -e "${YELLOW}${BOLD}METHOD 1: SECURITY DATABASE CHECK${NC}"
    echo ""
    
    # Known safe processes (expanded for beginners)
    known_safe="systemd sshd nginx apache2 httpd mysql mariadb postgresql redis mongodb docker containerd kubelet cron rsyslog NetworkManager snapd systemd-resolved systemd-timesyncd systemd-logind systemd-networkd pulseaudio pipewire gdm3 lightdm sddm cups avahi-daemon bluetooth ModemManager polkit udisks2 packagekit fwupd thermald irqbalance accounts-daemon chronyd ntpd named bind9 dhcpd dhclient postfix dovecot fail2ban ufw iptables firewalld auditd apparmor snapd flatpak systemd-journald systemd-udevd dbus rtkit colord whoopsie kerneloops acpid anacron atd unattended-upgrades update-notifier systemd-timesync systemd-hostnamed"
    
    # Known suspicious/malicious processes (expanded)
    known_suspicious="xmrig minergate minerd cpuminer cryptonight monero kworkerds kdevtmpfsi kinsing ddgs qW3xT.2 2t3ik .sshd dbused xmr crypto-pool minexmr pool.min bitcoin-miner litecoin-miner zcash-miner"
    
    if echo "$known_safe" | grep -qw "$clean_query"; then
        echo -e "${GREEN}✅ VERDICT: Known safe system service${NC}"
        echo -e "${BLUE}This is a standard Linux system service - perfectly normal!${NC}"
        
        # Provide specific information about common services for beginners
        case "$clean_query" in
            systemd) echo -e "${DIM}📝 System and service manager - the heart of modern Linux${NC}" ;;
            sshd) echo -e "${DIM}📝 SSH server - allows you to connect remotely to your VPS${NC}" ;;
            nginx) echo -e "${DIM}📝 Web server - serves websites and web applications${NC}" ;;
            apache2|httpd) echo -e "${DIM}📝 Apache web server - another popular web server${NC}" ;;
            mysql|mariadb) echo -e "${DIM}📝 Database server - stores data for websites and apps${NC}" ;;
            docker) echo -e "${DIM}📝 Container platform - runs applications in isolated environments${NC}" ;;
            cron) echo -e "${DIM}📝 Task scheduler - runs automated tasks at specific times${NC}" ;;
            fail2ban) echo -e "${DIM}📝 Security tool - blocks malicious login attempts${NC}" ;;
            ufw) echo -e "${DIM}📝 Firewall - controls network traffic to protect your VPS${NC}" ;;
            *) echo -e "${DIM}📝 This is a legitimate system component${NC}" ;;
        esac
        
    elif echo "$known_suspicious" | grep -qiw "$clean_query"; then
        echo -e "${RED}🚨 VERDICT: HIGHLY SUSPICIOUS - Known malware!${NC}"
        echo -e "${RED}This process is associated with cryptocurrency mining malware!${NC}"
        echo -e "${YELLOW}${BOLD}⚠️  BEGINNER-FRIENDLY ACTIONS:${NC}"
        echo -e "${YELLOW}1. Don't panic - your VPS is still controllable${NC}"
        echo -e "${YELLOW}2. Kill the process: ${CYAN}sudo pkill -f $clean_query${NC}"
        echo -e "${YELLOW}3. Check what it was doing: ${CYAN}sudo find / -name '*$clean_query*' 2>/dev/null${NC}"
        echo -e "${YELLOW}4. Consider asking for help on Linux forums${NC}"
        
    elif echo "$query" | grep -qE "(miner|xmrig|crypto|mine|pool)"; then
        echo -e "${RED}⚠️  VERDICT: Potentially malicious (mining-related keywords)${NC}"
        echo -e "${YELLOW}This might be cryptocurrency mining software (usually unauthorized)${NC}"
    else
        echo -e "${YELLOW}❓ Unknown process - needs investigation${NC}"
        echo -e "${CYAN}Don't worry! Many processes are just part of normal system operation.${NC}"
    fi
    
    # Method 2: Check running process details
    echo -e "\n${YELLOW}${BOLD}METHOD 2: LIVE PROCESS ANALYSIS${NC}"
    
    # Check if process is currently running
    pids=$(pgrep -f "$clean_query" 2>/dev/null)
    if [ -n "$pids" ]; then
        echo -e "${GREEN}✅ Process is currently running with PID(s): $pids${NC}"
        
        for pid in $pids; do
            if [ -d "/proc/$pid" ]; then
                echo -e "\n${BLUE}=== ANALYSIS FOR PID $pid ===${NC}"
                
                # Get command line - safe for beginners
                if [ -r "/proc/$pid/cmdline" ]; then
                    cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
                    echo -e "${CYAN}Command:${NC} ${cmdline:-[Hidden/System Process]}"
                fi
                
                # Get executable path - safe check
                if [ -r "/proc/$pid/exe" ]; then
                    exe_path=$(readlink -f /proc/$pid/exe 2>/dev/null)
                    echo -e "${CYAN}Executable:${NC} ${exe_path:-[System Process/Deleted]}"
                    
                    # Check if binary is in suspicious location (beginner-friendly explanation)
                    if echo "$exe_path" | grep -qE "(^/tmp|^/var/tmp|^/dev/shm)"; then
                        echo -e "${RED}⚠️  WARNING: Binary in temporary folder - could be malware!${NC}"
                        echo -e "${YELLOW}   Normal programs usually live in /usr/bin or /bin${NC}"
                    fi
                fi
                
                # Get process owner information
                if [ -r "/proc/$pid/status" ]; then
                    uid=$(grep -E "^Uid:" /proc/$pid/status 2>/dev/null | awk '{print $2}')
                    username=$(id -nu $uid 2>/dev/null || echo "UID:$uid")
                    echo -e "${CYAN}Running as user:${NC} $username"
                    
                    # Warn about root processes that shouldn't be root
                    if [ "$username" = "root" ] && echo "$clean_query" | grep -qE "(miner|crypto)"; then
                        echo -e "${RED}⚠️  WARNING: Suspicious process running as root!${NC}"
                    fi
                fi
                
                # Check CPU/Memory usage with safe handling
                if command -v ps &>/dev/null; then
                    stats=$(ps -p $pid -o %cpu,%mem --no-headers 2>/dev/null)
                    if [ -n "$stats" ]; then
                        cpu=$(echo "$stats" | awk '{print $1}')
                        mem=$(echo "$stats" | awk '{print $2}')
                        echo -e "${CYAN}Resource Usage:${NC} CPU: ${cpu}% | Memory: ${mem}%"
                        
                        # Flag high CPU usage with beginner explanation
                        if [ -n "$cpu" ] && [ "${cpu%.*}" -gt 80 ] 2>/dev/null; then
                            echo -e "${RED}⚠️  High CPU usage detected!${NC}"
                            echo -e "${YELLOW}   This process is using a lot of your server's power${NC}"
                        fi
                    fi
                fi
            fi
        done
    else
        echo -e "${DIM}Process not currently running${NC}"
    fi
    
    # Method 3: Check systemd service (beginner-friendly)
    echo -e "\n${YELLOW}${BOLD}METHOD 3: SYSTEM SERVICE CHECK${NC}"
    if systemctl list-unit-files 2>/dev/null | grep -q "^$query"; then
        echo -e "${GREEN}✅ Found as systemd service${NC}"
        
        # Get service status with error handling
        status=$(systemctl is-active "$query" 2>/dev/null || echo "unknown")
        enabled=$(systemctl is-enabled "$query" 2>/dev/null || echo "unknown")
        
        echo -e "Service Status: ${YELLOW}$status${NC} | Auto-start: ${YELLOW}$enabled${NC}"
        
        # Explain what this means for beginners
        case "$status" in
            active) echo -e "${GREEN}   ✅ Service is currently running${NC}" ;;
            inactive) echo -e "${YELLOW}   ⏸️  Service is stopped${NC}" ;;
            failed) echo -e "${RED}   ❌ Service failed to start${NC}" ;;
        esac
    else
        echo -e "${DIM}Not found as a systemd service${NC}"
    fi
    
    # Method 4: Beginner-friendly investigation commands
    echo -e "\n${YELLOW}${BOLD}METHOD 4: INVESTIGATION COMMANDS FOR BEGINNERS${NC}"
    
    echo -e "${BLUE}💡 Safe commands you can try:${NC}"
    echo -e "  ${CYAN}systemctl status $query              ${DIM}# Check service status${NC}"
    echo -e "  ${CYAN}ps aux | grep $clean_query           ${DIM}# See if it's running${NC}"
    echo -e "  ${CYAN}which $clean_query                   ${DIM}# Find where it's located${NC}"
    echo -e "  ${CYAN}man $clean_query                     ${DIM}# Read manual page${NC}"
    
    echo -e "\n${BLUE}🔍 Online research (safe to visit):${NC}"
    echo -e "  ${CYAN}1. Ubuntu packages: https://packages.ubuntu.com/search?keywords=$clean_query${NC}"
    echo -e "  ${CYAN}2. Process Library: https://www.processlibrary.com/en/search/?q=$clean_query${NC}"
    echo -e "  ${CYAN}3. Linux questions: https://askubuntu.com/search?q=$clean_query${NC}"
    
    # Educational note for beginners
    echo -e "\n${CYAN}📚 Learning Note:${NC}"
    echo -e "${DIM}Remember: Most processes on a Linux system are completely normal!${NC}"
    echo -e "${DIM}When in doubt, research first and ask questions in Linux communities.${NC}"
}

# Function to search for port information (enhanced for beginners)
search_port_info() {
    local port="$1"
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}🔍  SEARCHING FOR PORT: ${YELLOW}$port${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
    echo ""
    
    # Validate port number
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "${RED}❌ Invalid port number. Ports must be between 1 and 65535.${NC}"
        return 1
    fi
    
    # Extended common ports database with beginner explanations
    case $port in
        22) echo -e "${GREEN}✅ Port 22: SSH${NC}\n   ${CYAN}What it does:${NC} Secure remote access to your VPS\n   ${CYAN}Safety:${NC} Very important! This is how you connect to your server" ;;
        80) echo -e "${GREEN}✅ Port 80: HTTP Web${NC}\n   ${CYAN}What it does:${NC} Regular websites (not encrypted)\n   ${CYAN}Safety:${NC} Normal for web servers" ;;
        443) echo -e "${GREEN}✅ Port 443: HTTPS Web${NC}\n   ${CYAN}What it does:${NC} Secure websites (encrypted)\n   ${CYAN}Safety:${NC} Very safe, this is secure web traffic" ;;
        25) echo -e "${GREEN}✅ Port 25: SMTP Email${NC}\n   ${CYAN}What it does:${NC} Sends emails between servers\n   ${CYAN}Safety:${NC} Normal for mail servers" ;;
        53) echo -e "${GREEN}✅ Port 53: DNS${NC}\n   ${CYAN}What it does:${NC} Translates domain names to IP addresses\n   ${CYAN}Safety:${NC} Essential for internet connectivity" ;;
        3306) echo -e "${GREEN}✅ Port 3306: MySQL Database${NC}\n   ${CYAN}What it does:${NC} Database connections\n   ${CYAN}Safety:${NC} Normal for websites with databases" ;;
        3389) echo -e "${YELLOW}⚠️  Port 3389: Windows Remote Desktop${NC}\n   ${CYAN}What it does:${NC} Remote Windows desktop access\n   ${CYAN}Safety:${NC} Often attacked, secure it well!" ;;
        *) echo -e "${YELLOW}❓ Port not in beginner database - let's investigate...${NC}" ;;
    esac
    
    # Check what's actually using this port on your system
    echo -e "\n${YELLOW}${BOLD}WHAT'S USING THIS PORT ON YOUR VPS:${NC}"
    
    local_tcp=""
    local_udp=""
    
    if command -v ss &>/dev/null; then
        local_tcp=$(sudo ss -tlnp 2>/dev/null | grep ":$port ")
        local_udp=$(sudo ss -ulnp 2>/dev/null | grep ":$port ")
    fi
    
    if [ -n "$local_tcp" ] || [ -n "$local_udp" ]; then
        echo -e "${GREEN}✅ Port $port IS being used on your VPS:${NC}"
        
        if [ -n "$local_tcp" ]; then
            echo -e "${BLUE}TCP connections:${NC}"
            echo "$local_tcp" | while read line; do
                process=$(echo "$line" | grep -oP 'users:\(\("[^"]*' | cut -d'"' -f2 | head -1)
                echo -e "  ${CYAN}Process: ${process:-Unknown}${NC}"
            done
        fi
        
        if [ -n "$local_udp" ]; then
            echo -e "${BLUE}UDP connections:${NC}"
            echo "$local_udp" | while read line; do
                process=$(echo "$line" | grep -oP 'users:\(\("[^"]*' | cut -d'"' -f2 | head -1)
                echo -e "  ${CYAN}Process: ${process:-Unknown}${NC}"
            done
        fi
    else
        echo -e "${DIM}Port $port is NOT currently in use on your VPS${NC}"
        echo -e "${CYAN}This means no service is listening on this port right now${NC}"
    fi
    
    # Beginner-friendly investigation commands
    echo -e "\n${YELLOW}${BOLD}INVESTIGATION COMMANDS FOR BEGINNERS:${NC}"
    echo -e "${BLUE}💡 Safe commands you can try:${NC}"
    echo -e "  ${CYAN}sudo lsof -i :$port                    ${DIM}# See what's using this port${NC}"
    echo -e "  ${CYAN}sudo ss -tulpn | grep :$port           ${DIM}# Modern way to check ports${NC}"
}

# Function to show menu
show_menu() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}                                                          ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}        🔐  VPS SECURITY CHECK FOR BEGINNERS  🔐          ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}                                                          ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}Welcome, leesmith288! 👋${NC}"
    echo -e "${CYAN}This tool helps you understand what's running on your VPS.${NC}"
    echo -e "${CYAN}All checks are safe and won't break anything!${NC}"
    echo ""

    echo -e "${GREEN}${BOLD}BEGINNER-FRIENDLY SECURITY CHECKS:${NC}"
    echo ""
    echo -e "${YELLOW}  1)${NC} ${BOLD}🔍  Check Open Ports${NC} ${DIM}(what services are accessible)${NC}"
    echo ""
    echo -e "${YELLOW}  2)${NC} ${BOLD}💻  Check Running Processes${NC} ${DIM}(what programs are running)${NC}"
    echo ""
    echo -e "${YELLOW}  3)${NC} ${BOLD}🌐  Check Network Connections${NC} ${DIM}(who's connected)${NC}"
    echo ""
    echo -e "${YELLOW}  4)${NC} ${BOLD}🚪  Check SSH Security${NC} ${DIM}(login security)${NC}"
    echo ""
    echo -e "${YELLOW}  5)${NC} ${BOLD}🛡️   Check Fail2ban Status${NC} ${DIM}(attack protection)${NC}"
    echo ""
    echo -e "${RED}  0)${NC} ${BOLD}↩️   Exit${NC}"
    echo ""
}

# Main loop
while true; do
    show_menu
    
    read -p "$(echo -e ${BOLD}${YELLOW}'What would you like to check? (0-5): '${NC})" choice

    case $choice in
        1) # Port Scan with Search
            echo ""
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo -e "${CYAN}${BOLD}🔍  CHECKING OPEN PORTS ON YOUR VPS${NC}"
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo ""
            
            echo -e "${BLUE}📚 What this shows: Ports are like doors on your VPS.${NC}"
            echo -e "${BLUE}   Open ports allow services to communicate with the internet.${NC}"
            echo -e "${BLUE}   This is completely normal and necessary for your VPS to work!${NC}"
            echo ""
            
            echo -e "${YELLOW}${BOLD}PORTS CURRENTLY OPEN ON YOUR VPS:${NC}"
            echo ""
            
            # Get open ports with better formatting
            if command -v ss &>/dev/null; then
                echo -e "${CYAN}${BOLD}Port    Service                Description${NC}"
                echo -e "${CYAN}${BOLD}────    ───────                ───────────${NC}"
                
                # TCP ports
                sudo ss -tuln | grep LISTEN | awk '{print $5}' | sed 's/.*://' | sort -nu | while read port; do
                    if [ -n "$port" ]; then
                        # Get service name and process
                        service_line=$(sudo ss -tlnp | grep ":$port " | head -1)
                        process=$(echo "$service_line" | grep -oP 'users:\(\("[^"]*' | cut -d'"' -f2 | head -1)
                        
                        # Get service description from /etc/services
                        service_desc=$(grep -E "[[:space:]]$port/tcp" /etc/services 2>/dev/null | head -1 | awk '{print $1}')
                        
                        printf "${BLUE}%-8s${NC} %-22s ${DIM}%s${NC}\n" "$port" "${process:-Unknown}" "${service_desc:-Custom service}"
                    fi
                done
            else
                echo -e "${DIM}ss command not available, trying alternative...${NC}"
                sudo netstat -tuln 2>/dev/null | grep LISTEN | awk '{print $4}' | sed 's/.*://' | sort -nu | while read port; do
                    printf "${BLUE}Port %-6s${NC} → ${YELLOW}${BOLD}%-20s${NC}\n" "$port" "Active"
                done
            fi
            
            echo ""
            echo -e "${MAGENTA}${BOLD}Would you like detailed information about a specific port?${NC}"
            echo ""
            read -p "$(echo -e ${YELLOW}${BOLD}'Enter port number (or press Enter to skip): '${NC})" search_port
            
            if [[ "$search_port" =~ ^[0-9]+$ ]]; then
                search_port_info "$search_port"
            fi
            ;;
            
        2) # Process Check with Search
            echo ""
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo -e "${CYAN}${BOLD}💻  CHECKING RUNNING PROCESSES${NC}"
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo ""
            
            echo -e "${BLUE}📚 What this shows: All the programs currently running on your VPS.${NC}"
            echo -e "${BLUE}   Most of these are normal system processes that keep Linux working.${NC}"
            echo -e "${BLUE}   Don't worry if you see many processes - this is completely normal!${NC}"
            echo ""
            
            echo -e "${YELLOW}${BOLD}===== SYSTEM MEMORY USAGE =====${NC}"
            echo ""
            safe_command "free -h" "Memory usage check"
            
            echo ""
            echo -e "${YELLOW}${BOLD}===== PROCESSES USING CPU (>0.1%) =====${NC}"
            echo ""
            if safe_command "ps -eo pid,ppid,user,%cpu,%mem,stat,start,comm --sort=-%cpu" "CPU process list"; then
                ps -eo pid,ppid,user,%cpu,%mem,stat,start,comm --sort=-%cpu 2>/dev/null | awk 'NR==1 || $4>0.1' | head -15
            fi
            
            echo ""
            echo -e "${YELLOW}${BOLD}===== ACTIVE SYSTEM SERVICES =====${NC}"
            echo ""
            if safe_command "systemctl list-units --type=service --state=running --no-pager" "Active services"; then
                systemctl list-units --type=service --state=running --no-pager 2>/dev/null | head -20
            fi
            
            echo ""
            echo -e "${MAGENTA}${BOLD}Want to learn about a specific process or service?${NC}"
            echo ""
            read -p "$(echo -e ${YELLOW}${BOLD}'Enter process/service name (or press Enter to skip): '${NC})" search_proc
            
            if [ -n "$search_proc" ]; then
                search_process_info "$search_proc"
            fi
            ;;
            
        3) # Active Connections
            echo ""
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo -e "${CYAN}${BOLD}🌐  ACTIVE NETWORK CONNECTIONS${NC}"
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo ""
            
            echo -e "${BLUE}📚 What this shows: Who is currently connected to your VPS.${NC}"
            echo ""
            
            echo -e "${YELLOW}${BOLD}CURRENT LOGIN SESSIONS:${NC}"
            echo ""
            if safe_command "who" "User sessions"; then
                who_output=$(who)
                if [ -n "$who_output" ]; then
                    echo "$who_output"
                    session_count=$(echo "$who_output" | wc -l)
                    echo ""
                    echo -e "${CYAN}Total active sessions: $session_count${NC}"
                    if [ $session_count -gt 1 ]; then
                        echo -e "${YELLOW}💡 Multiple sessions detected. Make sure they're all yours!${NC}"
                    fi
                else
                    echo -e "${DIM}No active sessions shown${NC}"
                fi
            fi
            
            echo ""
            echo -e "${YELLOW}${BOLD}ESTABLISHED NETWORK CONNECTIONS:${NC}"
            echo ""
            if command -v ss &>/dev/null; then
                connections=$(sudo ss -tn state established 2>/dev/null | grep -v "Local Address")
                if [ -n "$connections" ]; then
                    echo -e "${CYAN}${BOLD}Local Address          Foreign Address${NC}"
                    echo -e "${CYAN}${BOLD}─────────────          ───────────────${NC}"
                    echo "$connections" | head -10 | while read line; do
                        local_addr=$(echo "$line" | awk '{print $4}')
                        foreign_addr=$(echo "$line" | awk '{print $5}')
                        echo -e "${GREEN}$local_addr${NC} ← → ${YELLOW}$foreign_addr${NC}"
                    done
                    
                    connection_count=$(echo "$connections" | wc -l)
                    echo ""
                    echo -e "${CYAN}Total connections: $connection_count${NC}"
                else
                    echo -e "${GREEN}✅ No unexpected connections detected${NC}"
                fi
            fi
            ;;
            
        4) # SSH Security
            echo ""
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo -e "${CYAN}${BOLD}🚪  SSH SECURITY CONFIGURATION${NC}"
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo ""
            
            echo -e "${BLUE}📚 What this shows: Your SSH settings control how securely you can connect to your VPS.${NC}"
            echo ""
            
            # Check SSH configuration safely
            if [ -f /etc/ssh/sshd_config ]; then
                SSH_PORT=$(sudo grep -E "^[[:space:]]*Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | tail -1)
                ROOT_LOGIN=$(sudo grep -E "^[[:space:]]*PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | tail -1)
                PASS_AUTH=$(sudo grep -E "^[[:space:]]*PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' | tail -1)
                
                # Use defaults if not explicitly set
                SSH_PORT=${SSH_PORT:-22}
                ROOT_LOGIN=${ROOT_LOGIN:-yes}
                PASS_AUTH=${PASS_AUTH:-yes}
                
                echo -e "${YELLOW}${BOLD}CURRENT SSH SECURITY SETTINGS:${NC}"
                echo ""
                
                # SSH Port Analysis
                echo -e "${BLUE}🔌 SSH Port:${NC}"
                if [ "$SSH_PORT" = "22" ]; then
                    echo -e "   ${YELLOW}⚠️  Using default port: $SSH_PORT${NC}"
                    echo -e "   ${CYAN}💡 Consider changing to a custom port for extra security${NC}"
                else
                    echo -e "   ${GREEN}✅ Using custom port: $SSH_PORT${NC}"
                    echo -e "   ${CYAN}💡 Good! Custom ports reduce automated attacks${NC}"
                fi
                echo ""
                
                # Root Login Analysis
                echo -e "${BLUE}👤 Root Login:${NC}"
                case "$ROOT_LOGIN" in
                    "yes")
                        echo -e "   ${RED}❌ Root login: ENABLED${NC}"
                        echo -e "   ${YELLOW}⚠️  Consider disabling and using sudo instead${NC}"
                        ;;
                    "no")
                        echo -e "   ${GREEN}✅ Root login: DISABLED${NC}"
                        echo -e "   ${CYAN}💡 Excellent security practice!${NC}"
                        ;;
                    *)
                        echo -e "   ${YELLOW}⚠️  Root login: $ROOT_LOGIN${NC}"
                        ;;
                esac
                echo ""
                
                # Password Authentication Analysis
                echo -e "${BLUE}🔑 Password Authentication:${NC}"
                case "$PASS_AUTH" in
                    "yes")
                        echo -e "   ${YELLOW}⚠️  Password auth: ENABLED${NC}"
                        echo -e "   ${CYAN}💡 Consider using SSH keys for better security${NC}"
                        ;;
                    "no")
                        echo -e "   ${GREEN}✅ Password auth: DISABLED${NC}"
                        echo -e "   ${CYAN}💡 Excellent! You're using SSH keys${NC}"
                        ;;
                    *)
                        echo -e "   ${YELLOW}❓ Password auth: $PASS_AUTH${NC}"
                        ;;
                esac
                
            else
                echo -e "${RED}❌ SSH configuration file not found${NC}"
            fi
            ;;
            
        5) # Fail2ban Status
            echo ""
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo -e "${CYAN}${BOLD}🛡️   FAIL2BAN PROTECTION STATUS${NC}"
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo ""
            
            echo -e "${BLUE}📚 What this shows: Fail2ban protects your VPS from brute force attacks.${NC}"
            echo ""
            
            # Check if fail2ban is installed
            if ! command -v fail2ban-client &>/dev/null; then
                echo -e "${RED}❌ Fail2ban is not installed${NC}"
                echo ""
                echo -e "${YELLOW}${BOLD}BEGINNER RECOMMENDATION:${NC}"
                echo -e "${CYAN}Fail2ban automatically protects your VPS from password attacks.${NC}"
                echo ""
                echo -e "${CYAN}To install fail2ban safely:${NC}"
                echo -e "${CYAN}   sudo apt update${NC}"
                echo -e "${CYAN}   sudo apt install fail2ban${NC}"
                echo -e "${CYAN}   sudo systemctl enable fail2ban${NC}"
                echo -e "${CYAN}   sudo systemctl start fail2ban${NC}"
            
            elif ! systemctl is-active --quiet fail2ban 2>/dev/null; then
                echo -e "${RED}❌ Fail2ban is installed but not running${NC}"
                echo ""
                echo -e "${YELLOW}${BOLD}TO START FAIL2BAN:${NC}"
                echo -e "${CYAN}   sudo systemctl start fail2ban${NC}"
                echo -e "${CYAN}   sudo systemctl enable fail2ban${NC}"
            
            else
                echo -e "${GREEN}✅ Fail2ban is active and protecting your VPS!${NC}"
                echo ""
                
                # Get all jails safely
                if JAILS=$(sudo fail2ban-client status 2>/dev/null | grep "Jail list" | sed 's/.*:\s*//' | tr ',' '\n' | sed 's/^\s*//'); then
                    
                    echo -e "${BLUE}${BOLD}📊 PROTECTION STATISTICS${NC}"
                    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo ""
                    
                    total_failed=0
                    total_banned=0
                    total_active=0
                    
                    for jail in $JAILS; do
                        if jail_status=$(sudo fail2ban-client status "$jail" 2>/dev/null); then
                            failed=$(echo "$jail_status" | grep "Total failed:" | awk '{print $NF}' || echo "0")
                            banned=$(echo "$jail_status" | grep "Total banned:" | awk '{print $NF}' || echo "0")
                            current=$(echo "$jail_status" | grep "Currently banned:" | awk '{print $NF}' || echo "0")
                            
                            echo -e "${YELLOW}${BOLD}🔒 $jail Protection:${NC}"
                            echo -e "   ${CYAN}Failed attempts blocked: ${BOLD}$failed${NC}"
                            echo -e "   ${CYAN}Total IPs banned: ${BOLD}$banned${NC}"
                            echo -e "   ${CYAN}Currently banned: ${BOLD}$current${NC}"
                            
                            if [ "$current" -gt 0 ]; then
                                echo -e "   ${RED}${BOLD}🚫 Currently banned IPs:${NC}"
                                banned_ips=$(sudo fail2ban-client status "$jail" 2>/dev/null | grep -A 100 "Banned IP list:" | grep -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" | head -5)
                                if [ -n "$banned_ips" ]; then
                                    echo "$banned_ips" | while read ip; do
                                        echo -e "      ${RED}$ip${NC}"
                                    done
                                fi
                            fi
                            echo ""
                        fi
                    done
                    
                    echo -e "${GREEN}${BOLD}✅ Your VPS is well protected!${NC}"
                fi
            fi
            ;;
            
        0) # Exit
            echo ""
            echo -e "${GREEN}${BOLD}Thanks for using VPS Security Check, leesmith288!${NC}"
            echo -e "${CYAN}Remember: When in doubt, research first and ask questions! 🤓${NC}"
            echo ""
            exit 0
            ;;
            
        *) 
            echo ""
            echo -e "${RED}${BOLD}Invalid option. Please choose 0-5.${NC}"
            echo ""
            ;;
    esac

    wait_for_enter
done
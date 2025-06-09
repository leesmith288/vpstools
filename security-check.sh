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

# Smart exit function
smart_exit() {
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        exit "${1:-0}"
    else
        return "${1:-0}"
    fi
}

# Then use it like:
0)
    echo "Exiting..."
    smart_exit 0
    ;;

# Add extra line spacing function
print_line() {
    echo -e "$1"
    echo ""  # Extra line for spacing
}

# Function to search for process/service information
search_process_info() {
    local query="$1"
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}🔍  SEARCHING FOR: ${YELLOW}$query${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
    echo ""
    
    # Clean the query
    clean_query=$(echo "$query" | sed 's/\.service$//')
    
    # Method 1: Local Security Database Check
    echo -e "${YELLOW}${BOLD}METHOD 1: SECURITY DATABASE CHECK${NC}"
    echo ""
    
    # Known safe processes (expanded)
    known_safe="systemd sshd nginx apache httpd mysql mariadb postgresql redis mongodb docker containerd kubelet cron rsyslog NetworkManager snapd systemd-resolved systemd-timesyncd systemd-logind systemd-networkd pulseaudio pipewire gdm lightdm sddm cups avahi bluetooth ModemManager polkit udisks2 packagekit fwupd thermald irqbalance accounts-daemon chronyd ntpd named bind dhcpd dhclient postfix dovecot fail2ban ufw iptables firewalld auditd apparmor snapd flatpak systemd-journald systemd-udevd dbus rtkit colord whoopsie kerneloops acpid anacron atd"
    
    # Known suspicious/malicious processes
    known_suspicious="xmrig minergate minerd cpuminer cryptonight monero kworkerds kdevtmpfsi kinsing ddgs qW3xT.2 2t3ik .sshd dbused xmr crypto-pool minexmr pool.min"
    
    # Known backdoors and rootkits
    known_backdoors="bindshell reverse-shell nc.traditional netcat ncat socat"
    
    if echo "$known_safe" | grep -qw "$clean_query"; then
        echo -e "${GREEN}✅ VERDICT: Known safe system service${NC}"
        echo -e "${BLUE}This is a standard Linux system service${NC}"
        
        # Provide specific information about common services
        case "$clean_query" in
            systemd) echo -e "${DIM}System and service manager for Linux${NC}" ;;
            sshd) echo -e "${DIM}OpenSSH server daemon for secure remote access${NC}" ;;
            nginx) echo -e "${DIM}High-performance web server and reverse proxy${NC}" ;;
            apache|httpd) echo -e "${DIM}Apache HTTP web server${NC}" ;;
            mysql|mariadb) echo -e "${DIM}Database server for storing application data${NC}" ;;
            docker) echo -e "${DIM}Container runtime for application deployment${NC}" ;;
            cron) echo -e "${DIM}Task scheduler for automated job execution${NC}" ;;
        esac
        
    elif echo "$known_suspicious" | grep -qiw "$clean_query"; then
        echo -e "${RED}⚠️  VERDICT: HIGHLY SUSPICIOUS - Known malware${NC}"
        echo -e "${RED}This process is associated with cryptocurrency mining malware!${NC}"
        echo -e "${YELLOW}Immediate action recommended:${NC}"
        echo -e "${YELLOW}1. Kill the process: sudo kill -9 \$(pgrep $clean_query)${NC}"
        echo -e "${YELLOW}2. Remove associated files${NC}"
        echo -e "${YELLOW}3. Check for persistence mechanisms${NC}"
        
    elif echo "$query" | grep -qE "(miner|xmrig|crypto|mine|pool)"; then
        echo -e "${RED}⚠️  VERDICT: Potentially malicious (mining-related keywords)${NC}"
    else
        echo -e "${YELLOW}❓ Unknown process - requires investigation${NC}"
    fi
    
    # Method 2: Check running process details
    echo -e "\n${YELLOW}Method 2: Live Process Analysis${NC}"
    
    # Check if process is currently running
    pids=$(pgrep -f "$clean_query" 2>/dev/null)
    if [ -n "$pids" ]; then
        echo -e "${GREEN}Process is currently running with PID(s): $pids${NC}"
        
        for pid in $pids; do
            if [ -d "/proc/$pid" ]; then
                echo -e "\n${BLUE}=== PID $pid Analysis ===${NC}"
                
                # Get command line
                if [ -r "/proc/$pid/cmdline" ]; then
                    cmdline=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
                    echo -e "${CYAN}Command:${NC} ${cmdline:-[Hidden]}"
                fi
                
                # Get executable path
                if [ -r "/proc/$pid/exe" ]; then
                    exe_path=$(readlink -f /proc/$pid/exe 2>/dev/null)
                    echo -e "${CYAN}Executable:${NC} ${exe_path:-[Deleted or Hidden]}"
                    
                    # Check if binary is in suspicious location
                    if echo "$exe_path" | grep -qE "(^/tmp|^/var/tmp|^/dev/shm)"; then
                        echo -e "${RED}⚠️  WARNING: Binary in suspicious location!${NC}"
                    fi
                fi
                
                # Get working directory
                if [ -r "/proc/$pid/cwd" ]; then
                    cwd=$(readlink -f /proc/$pid/cwd 2>/dev/null)
                    echo -e "${CYAN}Working Dir:${NC} ${cwd:-[Unknown]}"
                fi
                
                # Get process stats
                if [ -r "/proc/$pid/status" ]; then
                    uid=$(grep -E "^Uid:" /proc/$pid/status 2>/dev/null | awk '{print $2}')
                    username=$(id -nu $uid 2>/dev/null || echo "UID:$uid")
                    echo -e "${CYAN}Running as:${NC} $username"
                    
                    ppid=$(grep -E "^PPid:" /proc/$pid/status 2>/dev/null | awk '{print $2}')
                    if [ -n "$ppid" ] && [ "$ppid" -ne 0 ]; then
                        parent_cmd=$(ps -p $ppid -o comm= 2>/dev/null)
                        echo -e "${CYAN}Parent:${NC} $parent_cmd (PID: $ppid)"
                    fi
                fi
                
                # Check CPU/Memory usage
                if command -v ps &>/dev/null; then
                    stats=$(ps -p $pid -o %cpu,%mem 2>/dev/null | tail -1)
                    cpu=$(echo "$stats" | awk '{print $1}')
                    mem=$(echo "$stats" | awk '{print $2}')
                    echo -e "${CYAN}Resources:${NC} CPU: ${cpu}% | MEM: ${mem}%"
                    
                    # Flag high CPU usage
                    if [ -n "$cpu" ] && (( $(echo "$cpu > 80" | bc -l 2>/dev/null || echo 0) )); then
                        echo -e "${RED}⚠️  High CPU usage detected!${NC}"
                    fi
                fi
                
                # Check open files/connections
                echo -e "${CYAN}Network connections:${NC}"
                sudo lsof -p $pid 2>/dev/null | grep -E "(TCP|UDP)" | head -5 || echo "  None or access denied"
            fi
        done
    else
        echo -e "${DIM}Process not currently running${NC}"
    fi
    
    # Method 3: Check systemd service
    echo -e "\n${YELLOW}Method 3: System Service Check${NC}"
    if systemctl list-unit-files 2>/dev/null | grep -q "^$query"; then
        echo -e "${GREEN}Found as systemd service${NC}"
        
        # Get service status
        status=$(systemctl is-active "$query" 2>/dev/null || echo "unknown")
        enabled=$(systemctl is-enabled "$query" 2>/dev/null || echo "unknown")
        
        echo -e "Status: ${YELLOW}$status${NC} | Enabled: ${YELLOW}$enabled${NC}"
        
        # Get service details
        if [ "$status" = "active" ]; then
            # Show brief service info
            systemctl status "$query" --no-pager -n 0 2>/dev/null | grep -E "(Loaded:|Active:|Main PID:|Memory:|CPU:)" | head -5
        fi
    else
        echo -e "${DIM}Not found as a systemd service${NC}"
    fi
    
    # Method 4: Package information
    echo -e "\n${YELLOW}Method 4: Package Manager Check${NC}"
    pkg_found=false
    
    # Check dpkg (Debian/Ubuntu)
    if command -v dpkg &>/dev/null; then
        pkg_info=$(dpkg -l 2>/dev/null | grep -i "$clean_query" | head -3)
        if [ -n "$pkg_info" ]; then
            echo -e "${GREEN}Found in dpkg:${NC}"
            echo "$pkg_info"
            pkg_found=true
        fi
    fi
    
    # Check rpm (RedHat/CentOS)
    if ! $pkg_found && command -v rpm &>/dev/null; then
        pkg_info=$(rpm -qa 2>/dev/null | grep -i "$clean_query" | head -3)
        if [ -n "$pkg_info" ]; then
            echo -e "${GREEN}Found in rpm:${NC}"
            echo "$pkg_info"
            pkg_found=true
        fi
    fi
    
    $pkg_found || echo -e "${DIM}Not found in package manager${NC}"
    
    # Method 5: Security scan with available tools
    echo -e "\n${YELLOW}Method 5: Security Scan Results${NC}"
    
    # Check if common security tools are available
    if command -v rkhunter &>/dev/null; then
        echo -e "${CYAN}RKHunter check:${NC}"
        sudo rkhunter --check --skip-keypress --quiet --report-warnings-only 2>/dev/null | grep -i "$clean_query" || echo "  No warnings for this process"
    fi
    
    if command -v clamscan &>/dev/null; then
        echo -e "${CYAN}ClamAV check available${NC}"
        echo -e "${DIM}Run: clamscan --infected --recursive /path/to/check${NC}"
    fi
    
    # Method 6: Process forensics resources
    echo -e "\n${YELLOW}Method 6: Professional Resources & Commands${NC}"
    
    echo -e "${BLUE}Forensic investigation commands:${NC}"
    echo -e "  ${CYAN}sudo lsof -p \$(pgrep $clean_query)      ${DIM}# Open files${NC}"
    echo -e "  ${CYAN}sudo strace -p \$(pgrep $clean_query)     ${DIM}# System calls${NC}"
    echo -e "  ${CYAN}sudo netstat -tulpn | grep $clean_query   ${DIM}# Network connections${NC}"
    echo -e "  ${CYAN}strings /proc/\$(pgrep $clean_query)/exe  ${DIM}# Binary strings${NC}"
    echo -e "  ${CYAN}ls -la /proc/\$(pgrep $clean_query)/      ${DIM}# Process details${NC}"
    
    echo -e "\n${BLUE}Professional malware databases:${NC}"
    echo -e "  ${CYAN}1. VirusTotal: https://www.virustotal.com/gui/search/$clean_query${NC}"
    echo -e "  ${CYAN}2. Hybrid Analysis: https://www.hybrid-analysis.com/search?query=$clean_query${NC}"
    echo -e "  ${CYAN}3. MalwareBazaar: https://bazaar.abuse.ch/browse/tag/$clean_query/${NC}"
    echo -e "  ${CYAN}4. ProcessLibrary: https://www.processlibrary.com/en/search/?q=$clean_query${NC}"
    
    echo -e "\n${BLUE}Linux security resources:${NC}"
    echo -e "  ${CYAN}1. Linux Malware Detect: https://www.rfxn.com/projects/linux-malware-detect/${NC}"
    echo -e "  ${CYAN}2. SANS ISC: https://isc.sans.edu/search.html?q=$clean_query${NC}"
    echo -e "  ${CYAN}3. LinuxSecurity: https://linuxsecurity.com/search?q=$clean_query${NC}"
    
    # Method 7: Recommendations
    echo -e "\n${YELLOW}Method 7: Security Recommendations${NC}"
    
    if [ -n "$pids" ]; then
        # Process is running
        echo -e "${BLUE}Since this process is running:${NC}"
        echo -e "1. Monitor its behavior: ${CYAN}watch -n 1 'ps aux | grep $clean_query'${NC}"
        echo -e "2. Check persistence: ${CYAN}grep -r '$clean_query' /etc/systemd/system/ /etc/init.d/${NC}"
        echo -e "3. Review logs: ${CYAN}journalctl -u $query --since '1 hour ago'${NC}"
        echo -e "4. Scan for malware: ${CYAN}sudo maldet -a /proc/$pids/exe${NC}"
    else
        echo -e "${BLUE}To investigate further:${NC}"
        echo -e "1. Search in logs: ${CYAN}grep -i '$clean_query' /var/log/syslog${NC}"
        echo -e "2. Find files: ${CYAN}find / -name '*$clean_query*' 2>/dev/null${NC}"
        echo -e "3. Check startup: ${CYAN}systemctl list-unit-files | grep -i '$clean_query'${NC}"
    fi
    
    # Auto-detection for specific malware patterns
    if echo "$query" | grep -qiE "(kworker|kthread)" && [ -n "$exe_path" ] && [ "$exe_path" != "[kernel]" ]; then
        echo -e "\n${RED}⚠️  CRITICAL WARNING: Fake kernel thread detected!${NC}"
        echo -e "${RED}Real kernel threads should show [kernel] as exe path${NC}"
        echo -e "${RED}This is a common malware masquerading technique${NC}"
    fi
}

# Function to search for port information
search_port_info() {
    local port="$1"
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}🔍  SEARCHING FOR PORT: ${YELLOW}$port${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
    echo ""
    
    # First check local knowledge base
    echo -e "${YELLOW}${BOLD}LOCAL KNOWLEDGE BASE:${NC}"
    echo ""
    
    # Extended common ports database with more details
    case $port in
        20) echo -e "${GREEN}✅ Port 20: FTP Data Transfer${NC}\n   Protocol: TCP\n   Description: File Transfer Protocol data channel" ;;
        21) echo -e "${GREEN}✅ Port 21: FTP Control${NC}\n   Protocol: TCP\n   Description: File Transfer Protocol control channel" ;;
        22) echo -e "${GREEN}✅ Port 22: SSH (Secure Shell)${NC}\n   Protocol: TCP\n   Description: Secure remote login and command execution" ;;
        23) echo -e "${RED}⚠️  Port 23: Telnet${NC}\n   Protocol: TCP\n   Description: Unencrypted remote login (INSECURE)" ;;
        25) echo -e "${GREEN}✅ Port 25: SMTP${NC}\n   Protocol: TCP\n   Description: Simple Mail Transfer Protocol for email routing" ;;
        53) echo -e "${GREEN}✅ Port 53: DNS${NC}\n   Protocol: TCP/UDP\n   Description: Domain Name System resolution" ;;
        67) echo -e "${GREEN}✅ Port 67: DHCP Server${NC}\n   Protocol: UDP\n   Description: Dynamic Host Configuration Protocol server" ;;
        68) echo -e "${GREEN}✅ Port 68: DHCP Client${NC}\n   Protocol: UDP\n   Description: Dynamic Host Configuration Protocol client" ;;
        80) echo -e "${GREEN}✅ Port 80: HTTP${NC}\n   Protocol: TCP\n   Description: Hypertext Transfer Protocol (web traffic)" ;;
        110) echo -e "${GREEN}✅ Port 110: POP3${NC}\n   Protocol: TCP\n   Description: Post Office Protocol v3 for email retrieval" ;;
        143) echo -e "${GREEN}✅ Port 143: IMAP${NC}\n   Protocol: TCP\n   Description: Internet Message Access Protocol for email" ;;
        443) echo -e "${GREEN}✅ Port 443: HTTPS${NC}\n   Protocol: TCP\n   Description: HTTP over TLS/SSL (secure web traffic)" ;;
        445) echo -e "${YELLOW}⚠️  Port 445: SMB/CIFS${NC}\n   Protocol: TCP\n   Description: Server Message Block (Windows file sharing)" ;;
        587) echo -e "${GREEN}✅ Port 587: SMTP Submission${NC}\n   Protocol: TCP\n   Description: Email submission (authenticated SMTP)" ;;
        993) echo -e "${GREEN}✅ Port 993: IMAPS${NC}\n   Protocol: TCP\n   Description: IMAP over TLS/SSL" ;;
        995) echo -e "${GREEN}✅ Port 995: POP3S${NC}\n   Protocol: TCP\n   Description: POP3 over TLS/SSL" ;;
        1433) echo -e "${GREEN}✅ Port 1433: MS SQL Server${NC}\n   Protocol: TCP\n   Description: Microsoft SQL Server database" ;;
        3306) echo -e "${GREEN}✅ Port 3306: MySQL/MariaDB${NC}\n   Protocol: TCP\n   Description: MySQL and MariaDB database servers" ;;
        3389) echo -e "${YELLOW}⚠️  Port 3389: RDP${NC}\n   Protocol: TCP\n   Description: Remote Desktop Protocol (Windows)" ;;
        5355) echo -e "${GREEN}✅ Port 5355: LLMNR${NC}\n   Protocol: TCP/UDP\n   Description: Link-Local Multicast Name Resolution" ;;
        5432) echo -e "${GREEN}✅ Port 5432: PostgreSQL${NC}\n   Protocol: TCP\n   Description: PostgreSQL database server" ;;
        5900) echo -e "${YELLOW}⚠️  Port 5900: VNC${NC}\n   Protocol: TCP\n   Description: Virtual Network Computing (remote desktop)" ;;
        6379) echo -e "${GREEN}✅ Port 6379: Redis${NC}\n   Protocol: TCP\n   Description: Redis in-memory data structure store" ;;
        8080) echo -e "${YELLOW}⚠️  Port 8080: HTTP Alternate${NC}\n   Protocol: TCP\n   Description: Alternative HTTP port (often proxies)" ;;
        8443) echo -e "${GREEN}✅ Port 8443: HTTPS Alternate${NC}\n   Protocol: TCP\n   Description: Alternative HTTPS port" ;;
        27017) echo -e "${GREEN}✅ Port 27017: MongoDB${NC}\n   Protocol: TCP\n   Description: MongoDB NoSQL database" ;;
        *) echo -e "${YELLOW}❓ Port not in local database - searching online...${NC}" ;;
    esac
    
    # Method 1: Check /etc/services (most reliable local source)
    echo -e "\n${YELLOW}Method 1: System Services Database (/etc/services)${NC}"
    if [ -f /etc/services ]; then
        # Search for exact port match
        service_info=$(grep -E "^[a-zA-Z][a-zA-Z0-9-]*[[:space:]]+$port/(tcp|udp)" /etc/services 2>/dev/null | head -5)
        if [ -n "$service_info" ]; then
            echo -e "${GREEN}Found in system database:${NC}"
            echo "$service_info" | while IFS= read -r line; do
                service_name=$(echo "$line" | awk '{print $1}')
                protocol=$(echo "$line" | awk -F'/' '{print $2}' | awk '{print $1}')
                description=$(echo "$line" | sed 's/^[^#]*#//' | sed 's/^[[:space:]]*//')
                echo -e "  ${BLUE}Service: ${service_name}${NC}"
                echo -e "  ${BLUE}Protocol: ${protocol}${NC}"
                [ -n "$description" ] && echo -e "  ${BLUE}Description: ${description}${NC}"
                echo ""
            done
        else
            echo -e "${DIM}Port $port not found in /etc/services${NC}"
        fi
    fi
    
    # Method 2: Check IANA database (if we have it locally)
    echo -e "\n${YELLOW}Method 2: IANA Registry Information${NC}"
    
    # Download IANA CSV if not present (one-time)
    IANA_FILE="/tmp/iana-ports.csv"
    if [ ! -f "$IANA_FILE" ] || [ $(find "$IANA_FILE" -mtime +7 -print 2>/dev/null) ]; then
        echo -e "${DIM}Downloading latest IANA registry...${NC}"
        curl -s "https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.csv" > "$IANA_FILE" 2>/dev/null
    fi
    
    if [ -f "$IANA_FILE" ]; then
        # Search in IANA CSV
        iana_info=$(grep -E ",$port," "$IANA_FILE" 2>/dev/null | head -5)
        if [ -n "$iana_info" ]; then
            echo -e "${GREEN}IANA Registry entries:${NC}"
            echo "$iana_info" | while IFS=',' read -r service_name port_num protocol description assignee contact reg_date mod_date reference service_code unauthorized_use; do
                echo -e "  ${BLUE}Service: ${service_name}${NC}"
                echo -e "  ${BLUE}Protocol: ${protocol}${NC}"
                echo -e "  ${BLUE}Description: ${description}${NC}"
                [ -n "$assignee" ] && echo -e "  ${BLUE}Assignee: ${assignee}${NC}"
                [ -n "$reference" ] && echo -e "  ${BLUE}Reference: ${reference}${NC}"
                echo ""
            done
        else
            echo -e "${DIM}Port $port not found in IANA registry${NC}"
        fi
    else
        echo -e "${DIM}IANA database not available${NC}"
    fi
    
    # Method 3: Port range analysis and security assessment
    echo -e "\n${YELLOW}Method 3: Port Range Analysis${NC}"
    
    if [ $port -eq 0 ]; then
        echo -e "${RED}⚠️  Port 0: Reserved${NC}"
        echo -e "${YELLOW}Should not be used for services${NC}"
    elif [ $port -lt 1024 ]; then
        echo -e "${BLUE}Well-Known/System Port (0-1023)${NC}"
        echo -e "${YELLOW}Requires root/admin privileges to bind${NC}"
        echo -e "${YELLOW}Reserved for standard services by IANA${NC}"
    elif [ $port -lt 49152 ]; then
        echo -e "${BLUE}Registered/User Port (1024-49151)${NC}"
        echo -e "${YELLOW}Can be registered with IANA for specific services${NC}"
        echo -e "${YELLOW}Does not require special privileges${NC}"
    else
        echo -e "${BLUE}Dynamic/Private/Ephemeral Port (49152-65535)${NC}"
        echo -e "${YELLOW}Used for temporary connections${NC}"
        echo -e "${YELLOW}Should not be used for permanent services${NC}"
    fi
    
    # Method 4: Security assessment
    echo -e "\n${YELLOW}Method 4: Security Assessment${NC}"
    
    # Check for commonly exploited ports
    exploited_ports="23 135 139 445 1433 3389 5900"
    if echo "$exploited_ports" | grep -qw "$port"; then
        echo -e "${RED}⚠️  WARNING: This port is commonly targeted by attackers${NC}"
        echo -e "${YELLOW}Ensure proper security measures are in place${NC}"
    fi
    
    # Method 5: Online resources
    echo -e "\n${YELLOW}Method 5: Professional Online Resources${NC}"
    echo -e "${BLUE}For detailed information, visit these authoritative sources:${NC}"
    echo -e "  ${CYAN}1. IANA Official: https://www.iana.org/assignments/service-names-port-numbers${NC}"
    echo -e "  ${CYAN}2. SANS ISC: https://isc.sans.edu/port.html?port=$port${NC}"
    echo -e "  ${CYAN}3. SpeedGuide: https://www.speedguide.net/port.php?port=$port${NC}"
    echo -e "  ${CYAN}4. Wikipedia: https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers${NC}"
    
    # Try to fetch from web if curl and internet available
    if command -v curl &> /dev/null && ping -c 1 -W 2 google.com &>/dev/null; then
        echo -e "\n${DIM}Attempting to fetch current information...${NC}"
        
        # Try SANS API (if available)
        sans_info=$(timeout 5 curl -s "https://isc.sans.edu/api/port/$port" 2>/dev/null | grep -oP '(?<=<name>)[^<]+' | head -1)
        if [ -n "$sans_info" ]; then
            echo -e "${GREEN}SANS Database: $sans_info${NC}"
        fi
    fi
    
    # Method 6: Local service check
    echo -e "\n${YELLOW}Method 6: Local System Check${NC}"
    
    # Check if port is currently in use
    local_tcp=$(sudo ss -tlnp 2>/dev/null | grep ":$port ")
    local_udp=$(sudo ss -ulnp 2>/dev/null | grep ":$port ")
    
    if [ -n "$local_tcp" ] || [ -n "$local_udp" ]; then
        echo -e "${GREEN}Port $port is currently in use on this system:${NC}"
        [ -n "$local_tcp" ] && echo -e "${BLUE}TCP:${NC}\n$local_tcp"
        [ -n "$local_udp" ] && echo -e "${BLUE}UDP:${NC}\n$local_udp"
        
        # Extract process info
        if [ -n "$local_tcp" ]; then
            process=$(echo "$local_tcp" | grep -oP 'users:\(\("[^"]+' | cut -d'"' -f2 | head -1)
            [ -n "$process" ] && echo -e "\n${YELLOW}Process: $process${NC}"
        fi
    else
        echo -e "${DIM}Port $port is not currently in use locally${NC}"
    fi
    
    # Check for active connections
    active_conn=$(sudo ss -tan 2>/dev/null | grep ":$port " | wc -l)
    if [ $active_conn -gt 0 ]; then
        echo -e "\n${YELLOW}Active connections: $active_conn${NC}"
    fi
    
    echo -e "\n${CYAN}Investigation commands:${NC}"
    echo -e "${BLUE}  sudo lsof -i :$port              # Show processes using port${NC}"
    echo -e "${BLUE}  sudo netstat -tulpn | grep :$port # Alternative port check${NC}"
    echo -e "${BLUE}  sudo nmap -p $port localhost      # Scan specific port${NC}"
}

# Function to show menu
show_menu() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}                                                          ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}        🔐  VPS SECURITY CHECK + SEARCH  🔐               ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}${BOLD}                                                          ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo ""

    echo -e "${GREEN}${BOLD}SECURITY CHECKS:${NC}"
    echo ""
    echo -e "${YELLOW}  1)${NC} ${BOLD}🔍  Port Scan with Search${NC}"
    echo ""
    echo -e "${YELLOW}  2)${NC} ${BOLD}💻  Process Check with Search${NC}"
    echo ""
    echo -e "${YELLOW}  3)${NC} ${BOLD}🌐  Active Connections${NC}"
    echo ""
    echo -e "${YELLOW}  4)${NC} ${BOLD}🚪  SSH Security${NC}"
    echo ""
    echo -e "${YELLOW}  5)${NC} ${BOLD}🛡️   Fail2ban Advanced Status${NC}"
    echo ""
    echo ""
    echo -e "${RED}  0)${NC} ${BOLD}↩️   Exit${NC}"
    echo ""
    echo ""
}

# Main loop
while true; do
    show_menu
    
    read -p "$(echo -e ${BOLD}${YELLOW}'SELECT OPTION >>> '${NC})" choice

    case $choice in
        1) # Port Scan with Search
            echo ""
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo -e "${CYAN}${BOLD}🔍  PORT SCAN WITH SEARCH${NC}"
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo ""
            
            echo -e "${YELLOW}${BOLD}OPEN PORTS:${NC}"
            echo ""
            sudo ss -tuln | grep LISTEN | awk '{print $5}' | sed 's/.*://' | sort -nu | while read port; do
                service=$(sudo ss -tlnp | grep ":$port" | awk '{print $6}' | grep -oP '(?<=\().*?(?=\))' | head -1)
                printf "${BLUE}${BOLD}Port %-6s${NC} → ${YELLOW}${BOLD}%-20s${NC}\n" "$port" "${service:-Unknown}"
            done
            
            echo ""
            echo -e "${MAGENTA}${BOLD}Search for port information?${NC}"
            echo ""
            read -p "$(echo -e ${YELLOW}${BOLD}'Enter port number (or n to skip) >>> '${NC})" search_port
            
            [[ "$search_port" =~ ^[0-9]+$ ]] && search_port_info "$search_port"
            ;;
            
        2) # Process Check with Search
            echo ""
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo -e "${CYAN}${BOLD}💻  PROCESS CHECK WITH SEARCH${NC}"
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo ""
            
            echo -e "${YELLOW}${BOLD}===== SYSTEM RESOURCES =====${NC}"
            echo ""
            free -h
            
            echo ""
            echo -e "${YELLOW}${BOLD}===== CPU PROCESSES (>0.1% CPU) =====${NC}"
            echo ""
            ps -eo pid,ppid,user,%cpu,%mem,stat,start,comm --sort=-%cpu | awk 'NR==1 || $4>0.1'
            
            echo ""
            echo -e "${YELLOW}${BOLD}===== MEMORY PROCESSES (>0.1% MEM) =====${NC}"
            echo ""
            ps -eo pid,ppid,user,%cpu,%mem,stat,start,comm --sort=-%mem | awk 'NR==1 || $5>0.1'
            
            echo ""
            echo -e "${YELLOW}${BOLD}===== RUNNING SERVICES =====${NC}"
            echo ""
            systemctl list-units --type=service --state=running --no-pager | head -20
            
            echo ""
            echo -e "${YELLOW}${BOLD}===== FAILED SERVICES =====${NC}"
            echo ""
            systemctl list-units --state=failed
            
            echo ""
            echo -e "${MAGENTA}${BOLD}Search for process/service info?${NC}"
            echo ""
            read -p "$(echo -e ${YELLOW}${BOLD}'Enter process/service name (or n to skip) >>> '${NC})" search_proc
            
            [ "$search_proc" != "n" ] && [ -n "$search_proc" ] && search_process_info "$search_proc"
            ;;
            
        3) # Active Connections
            echo ""
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo -e "${CYAN}${BOLD}🌐  ACTIVE NETWORK CONNECTIONS${NC}"
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo ""
            
            echo -e "${YELLOW}${BOLD}CURRENT SSH SESSIONS:${NC}"
            echo ""
            who
            
            echo ""
            echo -e "${YELLOW}${BOLD}ESTABLISHED CONNECTIONS:${NC}"
            echo ""
            sudo ss -tn state established | grep -v "Local Address" | head -20
            ;;
            
        4) # SSH Security
            echo ""
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo -e "${CYAN}${BOLD}🚪  SSH SECURITY CONFIGURATION${NC}"
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo ""
            
            SSH_PORT=$(sudo grep -E "^Port" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "22")
            ROOT_LOGIN=$(sudo grep -E "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
            PASS_AUTH=$(sudo grep -E "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
            
            echo ""
            [ "$SSH_PORT" = "22" ] && echo -e "${YELLOW}${BOLD}⚠️  SSH Port:${NC} ${BOLD}Default (22)${NC}" || echo -e "${GREEN}${BOLD}✓ SSH Port:${NC} ${BOLD}$SSH_PORT${NC}"
            echo ""
            [ "$ROOT_LOGIN" = "yes" ] && echo -e "${RED}${BOLD}❌ Root Login:${NC} ${BOLD}Enabled${NC}" || echo -e "${GREEN}${BOLD}✓ Root Login:${NC} ${BOLD}Disabled${NC}"
            echo ""
            [ "$PASS_AUTH" = "yes" ] && echo -e "${YELLOW}${BOLD}⚠️  Password Auth:${NC} ${BOLD}Enabled${NC}" || echo -e "${GREEN}${BOLD}✓ Password Auth:${NC} ${BOLD}Disabled${NC}"
            echo ""
            ;;
            
        5) # Enhanced Fail2ban
            echo ""
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo -e "${CYAN}${BOLD}🛡️   FAIL2BAN ADVANCED STATUS${NC}"
            echo -e "${CYAN}${BOLD}═══════════════════════════════════════════${NC}"
            echo ""
            
            if ! systemctl is-active --quiet fail2ban 2>/dev/null; then
                echo -e "${RED}${BOLD}❌ Fail2ban not running${NC}"
                echo ""
                echo -e "${YELLOW}${BOLD}Start with: sudo systemctl start fail2ban${NC}"
            else
                echo -e "${GREEN}${BOLD}✅ Fail2ban is active${NC}"
                echo ""
                
                # Get all jails
                JAILS=$(sudo fail2ban-client status | grep "Jail list" | sed 's/.*:\s*//' | tr ',' '\n' | sed 's/^\s*//')
                
                echo -e "${BLUE}${BOLD}📊 JAIL STATISTICS${NC}"
                echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo ""
                
                for jail in $JAILS; do
                    if sudo fail2ban-client status "$jail" &>/dev/null; then
                        status=$(sudo fail2ban-client status "$jail")
                        failed=$(echo "$status" | grep "Total failed:" | awk '{print $NF}')
                        banned=$(echo "$status" | grep "Total banned:" | awk '{print $NF}')
                        current=$(echo "$status" | grep "Currently banned:" | awk '{print $NF}')
                        
                        echo -e "${YELLOW}${BOLD}$jail:${NC}"
                        echo -e "${BOLD}  Failed: $failed | Banned: $banned | Active: $current${NC}"
                        
                        if [ "$current" -gt 0 ]; then
                            echo -e "  ${RED}${BOLD}Banned IPs:${NC}"
                            sudo fail2ban-client status "$jail" | grep -A "$current" "Banned IP list:" | tail -n "$current" | sed 's/^/    /'
                        fi
                        echo ""
                    fi
                done
                
                # Recent activity
                if [ -f /var/log/fail2ban.log ]; then
                    echo -e "\n${BLUE}📅 RECENT BANS (Last 5)${NC}"
                    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    sudo grep "Ban" /var/log/fail2ban.log | tail -5 | sed 's/^/  /'
                fi
                
                # Geographic analysis using online API (no installation needed)
                echo -e "\n${BLUE}🌍 GEOGRAPHIC ANALYSIS${NC}"
                echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "${YELLOW}Checking banned IP locations...${NC}\n"
                
                # Get all currently banned IPs
                banned_ips=""
                for jail in $JAILS; do
                    if sudo fail2ban-client status "$jail" &>/dev/null; then
                        ips=$(sudo fail2ban-client status "$jail" 2>/dev/null | grep -A 100 "Banned IP list:" | grep -oE "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}")
                        banned_ips="$banned_ips $ips"
                    fi
                done
                
                # Remove duplicates and check each IP
                if [ -n "$banned_ips" ]; then
                    echo "$banned_ips" | tr ' ' '\n' | sort -u | head -10 | while read ip; do
                        if [ -n "$ip" ]; then
                            # Use online API - no installation needed!
                            location=$(curl -s "http://ip-api.com/json/$ip" 2>/dev/null | grep -oP '"country":\s*"\K[^"]+' || echo "Unknown")
                            city=$(curl -s "http://ip-api.com/json/$ip" 2>/dev/null | grep -oP '"city":\s*"\K[^"]+' || echo "")
                            
                            if [ -n "$city" ] && [ "$city" != "null" ]; then
                                echo -e "  ${RED}$ip${NC} → ${YELLOW}$city, $location${NC}"
                            else
                                echo -e "  ${RED}$ip${NC} → ${YELLOW}$location${NC}"
                            fi
                        fi
                    done
                    
                    echo -e "\n${DIM}Note: Location data from ip-api.com${NC}"
                else
                    echo -e "  ${DIM}No banned IPs to analyze${NC}"
                fi
            fi
            ;;
            
        0) # Exit
            echo ""
            echo -e "${GREEN}${BOLD}Exiting VPS Security Check...${NC}"
            echo ""
            exit 0
            ;;
            
        *) 
            echo ""
            echo -e "${RED}${BOLD}Invalid option${NC}"
            echo ""
            ;;
    esac

    echo ""
    echo -e "${YELLOW}${BOLD}Press Enter to return to menu...${NC}"
    read
done

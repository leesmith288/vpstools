#!/bin/bash
# Network Tools - Part of VPS Tools Suite
# Host as: network-tools.sh

# Colors - Enhanced for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Function to print with larger spacing
print_large() {
    echo -e "\n${BOLD}$1${NC}\n"
}

# Function to wait for user input (makes it more user-friendly)
wait_for_enter() {
    echo -e "\n${YELLOW}${BOLD}Press Enter to continue...${NC}"
    read
}

network_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}${BOLD}                 🌐 Network Tools                         ${NC}${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
        
        echo -e "${GREEN}${BOLD}Network Optimization:${NC}"
        echo -e "${YELLOW}  1)${NC} 🚀 Check BBR status"
        echo -e "${YELLOW}  2)${NC} ⚡ Enable BBR (if not enabled)"
        
        echo -e "\n${GREEN}${BOLD}Network Diagnostics:${NC}"
        echo -e "${YELLOW}  3)${NC} 🔍 MTR - Network route analysis"
        echo -e "${YELLOW}  4)${NC} 📊 Network speed test (with IPv4/IPv6 ping)"
        echo -e "${YELLOW}  5)${NC} 📡 Port connectivity test"
        
        echo -e "\n${GREEN}${BOLD}DNS Tools:${NC}"
        echo -e "${YELLOW}  6)${NC} 🔍 Check current DNS servers"
        echo -e "${YELLOW}  7)${NC} 🌐 Test DNS resolution"
        echo -e "${YELLOW}  8)${NC} ⚡ Change DNS servers"
        
        echo -e "\n${RED}  0)${NC} ↩️  Exit\n"
        
        read -p "$(echo -e ${BOLD}Select option: ${NC})" choice
        
        case $choice in
            1) # Check BBR
                clear
                print_large "🔍 Checking BBR status..."
                
                current_cc=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
                available_cc=$(sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | awk -F'=' '{print $2}' | xargs)
                
                echo -e "${BOLD}Current congestion control: ${YELLOW}$current_cc${NC}\n"
                echo -e "${BOLD}Available algorithms: ${YELLOW}$available_cc${NC}\n"
                
                if [[ "$current_cc" == *"bbr"* ]]; then
                    echo -e "${GREEN}${BOLD}✓ BBR is enabled!${NC}\n"
                    echo -e "${BOLD}BBR module status:${NC}"
                    lsmod | grep bbr || echo -e "${DIM}BBR module built into kernel${NC}"
                else
                    echo -e "${YELLOW}${BOLD}⚠️  BBR is not enabled${NC}\n"
                    echo -e "${DIM}BBR can improve network performance, especially for high-latency connections${NC}"
                fi
                
                wait_for_enter
                ;;
                
            2) # Enable BBR
                clear
                print_large "⚡ BBR Enabler"
                
                current_cc=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
                if [[ "$current_cc" == *"bbr"* ]]; then
                    echo -e "${GREEN}${BOLD}✓ BBR is already enabled!${NC}\n"
                else
                    echo -e "${YELLOW}${BOLD}BBR is not enabled. This can improve network performance.${NC}\n"
                    echo -e "${CYAN}${BOLD}What BBR does:${NC}"
                    echo -e "• Reduces network latency"
                    echo -e "• Improves throughput on high-latency connections"
                    echo -e "• Safe to enable on most systems\n"
                    
                    read -p "Enable BBR now? (y/N): " -n 1 -r
                    echo
                    
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        echo -e "${YELLOW}${BOLD}Creating backup of current configuration...${NC}"
                        sudo cp /etc/sysctl.conf /etc/sysctl.conf.backup
                        
                        echo -e "${YELLOW}${BOLD}Adding BBR configuration...${NC}"
                        echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf
                        echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf
                        
                        echo -e "${YELLOW}${BOLD}Applying changes...${NC}"
                        sudo sysctl -p
                        
                        # Wait a moment for changes to take effect
                        sleep 2
                        
                        new_cc=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
                        if [[ "$new_cc" == "bbr" ]]; then
                            echo -e "\n${GREEN}${BOLD}✓ BBR enabled successfully!${NC}\n"
                            echo -e "${CYAN}${BOLD}BBR is now active and will persist after reboot.${NC}"
                        else
                            echo -e "\n${RED}${BOLD}✗ Failed to enable BBR${NC}\n"
                            echo -e "${YELLOW}${BOLD}This may happen if your kernel doesn't support BBR.${NC}"
                            echo -e "${DIM}You can restore the original config with:${NC}"
                            echo -e "${DIM}sudo cp /etc/sysctl.conf.backup /etc/sysctl.conf${NC}"
                        fi
                    else
                        echo -e "${CYAN}${BOLD}BBR enablement cancelled.${NC}"
                    fi
                fi
                
                wait_for_enter
                ;;
                
            3) # MTR
                clear
                print_large "🔍 MTR - Network Route Analysis"
                echo -e "${CYAN}${BOLD}MTR shows the path your data takes to reach a destination.${NC}"
                echo -e "${CYAN}${BOLD}It's like traceroute but with continuous monitoring.${NC}\n"
                
                read -p "$(echo -e ${BOLD}Enter destination IP/domain \(e.g., google.com\): ${NC})" destination
                
                if [ -n "$destination" ]; then
                    if command -v mtr &> /dev/null; then
                        echo -e "\n${GREEN}${BOLD}Running MTR to $destination...${NC}"
                        echo -e "${DIM}Press 'q' to quit when done viewing${NC}\n"
                        sleep 2
                        sudo mtr "$destination"
                    else
                        echo -e "${YELLOW}${BOLD}MTR not installed. Installing it now...${NC}\n"
                        echo -e "${CYAN}${BOLD}MTR is a safe network diagnostic tool.${NC}"
                        read -p "Install MTR? (y/N): " -n 1 -r
                        echo
                        if [[ $REPLY =~ ^[Yy]$ ]]; then
                            if [ -f /etc/debian_version ]; then
                                sudo apt update && sudo apt install -y mtr-tiny
                            elif [ -f /etc/redhat-release ]; then
                                sudo yum install -y mtr || sudo dnf install -y mtr
                            fi
                            
                            if command -v mtr &> /dev/null; then
                                echo -e "\n${GREEN}${BOLD}MTR installed successfully!${NC}\n"
                                sleep 1
                                sudo mtr "$destination"
                            else
                                echo -e "\n${RED}${BOLD}Failed to install MTR${NC}"
                            fi
                        fi
                    fi
                else
                    echo -e "${RED}${BOLD}No destination specified.${NC}"
                fi
                
                wait_for_enter
                ;;
                
            4) # Speed test with ping
                clear
                print_large "📊 Network Speed & Connectivity Test"
                
                echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}\n"
                echo -e "${YELLOW}${BOLD}1. IPv4 Connectivity Test${NC}\n"
                
                # IPv4 Ping Test - simplified to 2 hosts
                echo -e "${BOLD}Testing Cloudflare DNS (1.1.1.1):${NC}"
                if ping -4 -c 4 -W 2 1.1.1.1 2>/dev/null | grep -E "(bytes from|min/avg/max)" | sed 's/^/  /'; then
                    echo -e "  ${GREEN}${BOLD}✓ IPv4 connectivity working${NC}"
                else
                    echo -e "  ${RED}${BOLD}✗ IPv4 connectivity issue${NC}"
                fi
                echo
                
                echo -e "${BOLD}Testing Google (google.com):${NC}"
                if ping -4 -c 4 -W 2 google.com 2>/dev/null | grep -E "(bytes from|min/avg/max)" | sed 's/^/  /'; then
                    echo -e "  ${GREEN}${BOLD}✓ DNS resolution working${NC}"
                else
                    echo -e "  ${RED}${BOLD}✗ DNS resolution issue${NC}"
                fi
                echo
                
                echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}\n"
                echo -e "${YELLOW}${BOLD}2. IPv6 Connectivity Test${NC}\n"
                
                # IPv6 Ping Test
                if ping -6 -c 1 -W 2 2001:4860:4860::8888 &>/dev/null; then
                    echo -e "${BOLD}Testing Google DNS IPv6 (2001:4860:4860::8888):${NC}"
                    ping -6 -c 4 -W 2 2001:4860:4860::8888 2>/dev/null | grep -E "(bytes from|min/avg/max)" | sed 's/^/  /'
                    echo
                    
                    echo -e "${BOLD}Testing Google IPv6 (google.com):${NC}"
                    ping -6 -c 4 -W 2 google.com 2>/dev/null | grep -E "(bytes from|min/avg/max)" | sed 's/^/  /'
                    echo
                    echo -e "  ${GREEN}${BOLD}✓ IPv6 connectivity working${NC}"
                else
                    echo -e "${RED}${BOLD}⚠️  IPv6 connectivity not available on this system${NC}\n"
                    echo -e "${YELLOW}${BOLD}This VPS does not have IPv6 configured or enabled.${NC}"
                    echo -e "${DIM}This is normal for many VPS providers.${NC}\n"
                fi
                
                echo -e "${CYAN}${BOLD}═══════════════════════════════════════${NC}\n"
                echo -e "${YELLOW}${BOLD}3. Speed Test Options:${NC}\n"
                echo -e "${BOLD}1) Fast.com (simple, works with most firewalls)${NC}"
                echo -e "${BOLD}2) Speedtest CLI (detailed results)${NC}"
                echo -e "${BOLD}3) LibreSpeed (browser-based, manual)${NC}"
                echo -e "${BOLD}4) Skip speed test${NC}\n"
                read -p "$(echo -e ${BOLD}Select \(1-4\): ${NC})" method
                
                case $method in
                    1)
                        echo -e "\n${GREEN}${BOLD}Testing with Fast.com method...${NC}\n"
                        if command -v python3 &> /dev/null; then
                            curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 - --simple 2>/dev/null || echo -e "${RED}${BOLD}Speed test failed - network issue or tool unavailable${NC}"
                        else
                            echo -e "${RED}${BOLD}Python3 not available for speed test${NC}"
                        fi
                        ;;
                    2)
                        if command -v speedtest-cli &> /dev/null; then
                            echo -e "\n${GREEN}${BOLD}Running Speedtest...${NC}\n"
                            speedtest-cli
                        else
                            echo -e "${YELLOW}${BOLD}Installing speedtest-cli...${NC}\n"
                            if command -v python3 &> /dev/null; then
                                curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 - 2>/dev/null || echo -e "${RED}${BOLD}Speed test failed${NC}"
                            else
                                echo -e "${RED}${BOLD}Python3 required for speedtest-cli${NC}"
                            fi
                        fi
                        ;;
                    3)
                        echo -e "\n${BLUE}${BOLD}Manual browser test:${NC}"
                        echo -e "${GREEN}${BOLD}Open this URL in your browser: https://librespeed.org/${NC}"
                        echo -e "${DIM}This will test from your local computer's connection${NC}\n"
                        ;;
                    4)
                        echo -e "\n${YELLOW}${BOLD}Speed test skipped${NC}\n"
                        ;;
                    *)
                        echo -e "\n${RED}${BOLD}Invalid option${NC}\n"
                        ;;
                esac
                
                wait_for_enter
                ;;
                
            5) # Port test
                clear
                print_large "📡 Port Connectivity Test"
                echo -e "${CYAN}${BOLD}Test if a specific port is open on a remote server.${NC}"
                echo -e "${CYAN}${BOLD}Useful for checking if services are running and accessible.${NC}\n"
                
                read -p "$(echo -e ${BOLD}Enter host/IP \(e.g., google.com\): ${NC})" host
                read -p "$(echo -e ${BOLD}Enter port \(e.g., 80, 443, 22\): ${NC})" port
                
                if [ -n "$host" ] && [ -n "$port" ]; then
                    echo -e "\n${YELLOW}${BOLD}Testing $host:$port...${NC}\n"
                    
                    # Test with timeout to avoid hanging
                    if timeout 5 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
                        echo -e "${GREEN}${BOLD}✓ Port $port is open on $host${NC}"
                        echo -e "${DIM}  The service is running and accepting connections${NC}\n"
                    else
                        echo -e "${RED}${BOLD}✗ Port $port is closed or filtered on $host${NC}"
                        echo -e "${DIM}  The service may not be running or is blocked by firewall${NC}\n"
                    fi
                    
                    # Additional test with netcat if available
                    if command -v nc &> /dev/null; then
                        echo -e "${YELLOW}${BOLD}Detailed test with netcat:${NC}"
                        nc -zv "$host" "$port" 2>&1 | sed 's/^/  /'
                    else
                        echo -e "${DIM}Install netcat (nc) for more detailed port testing${NC}"
                    fi
                else
                    echo -e "${RED}${BOLD}Both host and port are required.${NC}"
                fi
                
                wait_for_enter
                ;;
                
            6) # Current DNS
                clear
                print_large "🔍 Current DNS Configuration"
                
                echo -e "${YELLOW}${BOLD}System DNS servers (from /etc/resolv.conf):${NC}\n"
                if [ -f /etc/resolv.conf ]; then
                    if grep "^nameserver" /etc/resolv.conf; then
                        grep "^nameserver" /etc/resolv.conf | while read -r line; do
                            echo -e "  ${BOLD}${line}${NC}"
                        done
                    else
                        echo -e "  ${YELLOW}${BOLD}No nameservers found in /etc/resolv.conf${NC}"
                    fi
                else
                    echo -e "  ${RED}${BOLD}/etc/resolv.conf not found${NC}"
                fi
                
                echo -e "\n${YELLOW}${BOLD}Network interface DNS (if using systemd-resolved):${NC}\n"
                if command -v resolvectl &> /dev/null; then
                    resolvectl status 2>/dev/null | grep -E "(DNS Servers|DNS Domain)" | sed 's/^/  /' || echo -e "  ${DIM}No systemd-resolved info available${NC}"
                elif command -v systemd-resolve &> /dev/null; then
                    systemd-resolve --status 2>/dev/null | grep -E "(DNS Servers|DNS Domain)" | sed 's/^/  /' || echo -e "  ${DIM}No systemd-resolved info available${NC}"
                else
                    echo -e "  ${DIM}systemd-resolved not in use${NC}"
                fi
                
                echo -e "\n${YELLOW}${BOLD}Testing DNS resolution capability:${NC}\n"
                if getent hosts google.com >/dev/null 2>&1; then
                    echo -e "  ${GREEN}${BOLD}✓ DNS resolution is working properly${NC}"
                    resolved_ip=$(getent hosts google.com | awk '{print $1}' | head -1)
                    echo -e "  ${DIM}google.com resolves to: $resolved_ip${NC}"
                else
                    echo -e "  ${RED}${BOLD}✗ DNS resolution appears to be broken${NC}"
                    echo -e "  ${YELLOW}${BOLD}You may need to fix your DNS configuration${NC}"
                fi
                
                wait_for_enter
                ;;
                
            7) # Test DNS
                clear
                print_large "🌐 DNS Resolution Test"
                read -p "$(echo -e ${BOLD}Enter domain to test \(default: google.com\): ${NC})" domain
                domain=${domain:-google.com}
                
                echo -e "\n${YELLOW}${BOLD}Testing DNS resolution for: $domain${NC}\n"
                
                # Test with getent (uses system resolver)
                echo -e "${BLUE}${BOLD}System DNS Resolution:${NC}"
                result=$(getent hosts "$domain" 2>/dev/null)
                if [ -n "$result" ]; then
                    echo "$result" | while read -r line; do
                        echo -e "  ${BOLD}$line${NC}"
                    done
                else
                    echo -e "  ${RED}${BOLD}Failed to resolve using system DNS${NC}"
                fi
                
                # Test with different DNS servers using simple method
                echo -e "\n${BLUE}${BOLD}Testing with popular DNS servers:${NC}\n"
                
                # Function to test DNS using a specific server
                test_dns_server() {
                    local dns_name=$1
                    local dns_ip=$2
                    echo -n "  ${BOLD}$dns_name ($dns_ip): ${NC}"
                    
                    # Try to use nslookup if available, otherwise use ping test
                    if command -v nslookup &> /dev/null; then
                        if result=$(nslookup "$domain" "$dns_ip" 2>/dev/null); then
                            ip=$(echo "$result" | grep -A1 "Name:" | grep "Address:" | tail -1 | awk '{print $2}' 2>/dev/null)
                            if [ -n "$ip" ]; then
                                echo -e "${GREEN}${BOLD}✓ $ip${NC}"
                            else
                                # Alternative parsing for different nslookup formats
                                ip=$(echo "$result" | grep "^Address:" | grep -v "#53" | head -1 | awk '{print $2}' 2>/dev/null)
                                if [ -n "$ip" ]; then
                                    echo -e "${GREEN}${BOLD}✓ $ip${NC}"
                                else
                                    echo -e "${YELLOW}${BOLD}? Resolved but format unclear${NC}"
                                fi
                            fi
                        else
                            echo -e "${RED}${BOLD}✗ Failed${NC}"
                        fi
                    else
                        # Fallback: test if we can reach the DNS server
                        if ping -c 1 -W 1 "$dns_ip" &>/dev/null; then
                            echo -e "${YELLOW}${BOLD}? Server reachable (install dnsutils for detailed test)${NC}"
                        else
                            echo -e "${RED}${BOLD}✗ Unreachable${NC}"
                        fi
                    fi
                }
                
                test_dns_server "Cloudflare" "1.1.1.1"
                test_dns_server "Google" "8.8.8.8"
                test_dns_server "Quad9" "9.9.9.9"
                
                echo -e "\n${YELLOW}${BOLD}Alternative test using ping:${NC}"
                echo -n "  ${BOLD}Ping test for $domain: ${NC}"
                if ping_result=$(ping -c 1 -W 2 "$domain" 2>/dev/null); then
                    ip=$(echo "$ping_result" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
                    echo -e "${GREEN}${BOLD}✓ Resolves to $ip${NC}"
                else
                    echo -e "${RED}${BOLD}✗ Cannot resolve or reach${NC}"
                fi
                
                # Show installation hint if nslookup is missing
                if ! command -v nslookup &> /dev/null; then
                    echo -e "\n${CYAN}${BOLD}💡 Tip: For better DNS testing, install dnsutils:${NC}"
                    echo -e "${DIM}   Ubuntu/Debian: sudo apt install dnsutils${NC}"
                    echo -e "${DIM}   CentOS/RHEL: sudo yum install bind-utils${NC}"
                fi
                
                wait_for_enter
                ;;
                
            8) # Change DNS
                clear
                print_large "⚡ Change DNS Servers"
                
                echo -e "${CYAN}${BOLD}DNS servers translate domain names to IP addresses.${NC}"
                echo -e "${CYAN}${BOLD}Different DNS servers offer different benefits.${NC}\n"
                
                echo -e "${YELLOW}${BOLD}Popular DNS servers:${NC}\n"
                echo -e "${BOLD}1) Cloudflare (1.1.1.1, 1.0.0.1) - Privacy focused, fast${NC}"
                echo -e "${BOLD}2) Google (8.8.8.8, 8.8.4.4) - Fast & reliable${NC}"
                echo -e "${BOLD}3) Quad9 (9.9.9.9, 149.112.112.112) - Security focused${NC}"
                echo -e "${BOLD}4) OpenDNS (208.67.222.222, 208.67.220.220) - Family safe${NC}"
                echo -e "${BOLD}5) Custom DNS servers${NC}"
                echo -e "${BOLD}0) Cancel${NC}\n"
                
                read -p "$(echo -e ${BOLD}Select option: ${NC})" dns_choice
                
                case $dns_choice in
                    1) dns1="1.1.1.1"; dns2="1.0.0.1"; provider="Cloudflare" ;;
                    2) dns1="8.8.8.8"; dns2="8.8.4.4"; provider="Google" ;;
                    3) dns1="9.9.9.9"; dns2="149.112.112.112"; provider="Quad9" ;;
                    4) dns1="208.67.222.222"; dns2="208.67.220.220"; provider="OpenDNS" ;;
                    5) 
                        read -p "$(echo -e ${BOLD}Enter primary DNS: ${NC})" dns1
                        read -p "$(echo -e ${BOLD}Enter secondary DNS \(optional\): ${NC})" dns2
                        provider="Custom"
                        ;;
                    0) continue ;;
                    *) echo -e "${RED}${BOLD}Invalid option${NC}"; sleep 2; continue ;;
                esac
                
                if [ -n "$dns1" ]; then
                    echo -e "\n${YELLOW}${BOLD}⚠️  Important DNS Change Information:${NC}"
                    echo -e "${CYAN}• This will change your system's DNS temporarily${NC}"
                    echo -e "${CYAN}• Changes may be reset by DHCP or network restart${NC}"
                    echo -e "${CYAN}• Your current config will be backed up${NC}\n"
                    
                    read -p "Continue with $provider DNS? (y/N): " -n 1 -r
                    echo
                    
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        echo -e "\n${YELLOW}${BOLD}Backing up current configuration...${NC}"
                        sudo cp /etc/resolv.conf /etc/resolv.conf.backup.$(date +%Y%m%d-%H%M%S)
                        
                        echo -e "${YELLOW}${BOLD}Setting new DNS servers...${NC}"
                        echo "# DNS servers changed by network-tools.sh" | sudo tee /etc/resolv.conf > /dev/null
                        echo "nameserver $dns1" | sudo tee -a /etc/resolv.conf > /dev/null
                        [ -n "$dns2" ] && echo "nameserver $dns2" | sudo tee -a /etc/resolv.conf > /dev/null
                        
                        echo -e "\n${GREEN}${BOLD}✓ DNS servers updated to $provider!${NC}\n"
                        echo -e "${YELLOW}${BOLD}New configuration:${NC}\n"
                        cat /etc/resolv.conf | while read -r line; do
                            [[ "$line" =~ ^# ]] && echo -e "  ${DIM}$line${NC}" || echo -e "  ${BOLD}$line${NC}"
                        done
                        
                        echo -e "\n${YELLOW}${BOLD}Testing new DNS configuration...${NC}"
                        sleep 1
                        if getent hosts google.com >/dev/null 2>&1; then
                            echo -e "${GREEN}${BOLD}✓ DNS resolution working with new servers${NC}"
                            resolved_ip=$(getent hosts google.com | awk '{print $1}' | head -1)
                            echo -e "${DIM}google.com resolves to: $resolved_ip${NC}"
                        else
                            echo -e "${RED}${BOLD}✗ DNS resolution failed - reverting changes${NC}"
                            sudo cp /etc/resolv.conf.backup.* /etc/resolv.conf 2>/dev/null || true
                            echo -e "${YELLOW}${BOLD}Original configuration restored${NC}"
                        fi
                        
                        echo -e "\n${BLUE}${BOLD}📝 Notes:${NC}"
                        echo -e "${CYAN}• For permanent changes, edit your network configuration${NC}"
                        echo -e "${CYAN}• To revert manually: sudo cp /etc/resolv.conf.backup.* /etc/resolv.conf${NC}"
                        echo -e "${CYAN}• Changes may reset after reboot or network restart${NC}"
                    else
                        echo -e "${CYAN}${BOLD}DNS change cancelled.${NC}"
                    fi
                fi
                
                wait_for_enter
                ;;
                
            0) exit 0 ;;
            *) echo -e "${RED}${BOLD}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

# Start
network_menu
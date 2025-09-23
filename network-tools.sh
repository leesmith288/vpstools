#!/bin/bash
# Network Tools - Part of VPS Tools Suite
# Host as: network-tools.sh

# Colors - Enhanced for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Function to print with larger spacing
print_large() {
    echo -e "\n${BOLD}$1${NC}\n"
}

# Function to print success message
print_success() {
    echo -e "${GREEN}${BOLD}✓ $1${NC}"
}

# Function to print error message
print_error() {
    echo -e "${RED}${BOLD}✗ $1${NC}"
}

# Function to print warning message
print_warning() {
    echo -e "${YELLOW}${BOLD}⚠️  $1${NC}"
}

# Function to print info message
print_info() {
    echo -e "${BLUE}${BOLD}ℹ️  $1${NC}"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Function to detect OS
detect_os() {
    if [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "redhat"
    elif [ -f /etc/arch-release ]; then
        echo "arch"
    else
        echo "unknown"
    fi
}

# BBR Functions
check_bbr_status() {
    local current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    local available_cc=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null)
    local current_qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}              BBR Status Information                      ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${BOLD}Current Settings:${NC}"
    echo -e "  ${BOLD}Congestion Control:${NC} ${YELLOW}$current_cc${NC}"
    echo -e "  ${BOLD}Queue Discipline:${NC} ${YELLOW}$current_qdisc${NC}"
    echo -e "  ${BOLD}Available Algorithms:${NC} ${YELLOW}$available_cc${NC}\n"
    
    # Check if BBR module is loaded
    echo -e "${BOLD}Module Status:${NC}"
    if lsmod | grep -q tcp_bbr; then
        print_success "BBR module is loaded"
        echo -e "  ${DIM}$(lsmod | grep tcp_bbr)${NC}"
    else
        print_warning "BBR module is not loaded"
    fi
    
    echo -e "\n${BOLD}Overall Status:${NC}"
    if [[ "$current_cc" == "bbr" ]] || [[ "$current_cc" == "bbr2" ]]; then
        print_success "BBR is enabled and active!"
        if [[ "$current_qdisc" == "fq" ]]; then
            print_success "FQ queue discipline is properly configured"
        else
            print_warning "Queue discipline is $current_qdisc (recommended: fq)"
        fi
    else
        print_warning "BBR is not enabled (using $current_cc)"
        if [[ "$available_cc" == *"bbr"* ]]; then
            print_info "BBR is available and can be enabled"
        else
            print_error "BBR is not available in your kernel"
        fi
    fi
}

enable_bbr() {
    local current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    local available_cc=$(sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null)
    
    # Check if already enabled
    if [[ "$current_cc" == "bbr" ]] || [[ "$current_cc" == "bbr2" ]]; then
        print_success "BBR is already enabled and active!"
        local current_qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)
        if [[ "$current_qdisc" != "fq" ]]; then
            print_warning "Queue discipline is $current_qdisc instead of fq"
            echo -e "${YELLOW}Would you like to set it to fq for optimal performance?${NC}"
            read -p "Continue? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
                if ! grep -q "^net.core.default_qdisc=fq" /etc/sysctl.conf 2>/dev/null; then
                    echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf >/dev/null
                else
                    sudo sed -i 's/^net.core.default_qdisc=.*/net.core.default_qdisc=fq/' /etc/sysctl.conf
                fi
                print_success "Queue discipline updated to fq"
            fi
        fi
        return 0
    fi
    
    # Check if BBR is available
    if [[ "$available_cc" != *"bbr"* ]]; then
        print_error "BBR is not available in your kernel!"
        echo -e "${YELLOW}Your kernel version: $(uname -r)${NC}"
        echo -e "${YELLOW}BBR requires kernel 4.9 or newer${NC}"
        return 1
    fi
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}              BBR Installation Process                    ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${YELLOW}${BOLD}This will enable BBR congestion control for better network performance.${NC}"
    echo -e "${BOLD}Current: ${RED}$current_cc${NC} → ${BOLD}Target: ${GREEN}BBR${NC}\n"
    
    read -p "$(echo -e ${BOLD}Proceed with BBR installation? \(y/N\): ${NC})" -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Installation cancelled"
        return 1
    fi
    
    echo -e "\n${BOLD}Step 1/5: Creating configuration backup...${NC}"
    local backup_file="/etc/sysctl.conf.backup.$(date +%Y%m%d_%H%M%S)"
    sudo cp /etc/sysctl.conf "$backup_file"
    print_success "Backup created: $backup_file"
    
    echo -e "\n${BOLD}Step 2/5: Loading BBR kernel module...${NC}"
    if ! lsmod | grep -q tcp_bbr; then
        if sudo modprobe tcp_bbr 2>/dev/null; then
            print_success "BBR module loaded successfully"
        else
            print_error "Failed to load BBR module"
            return 1
        fi
        
        # Add to modules to load at boot
        if ! grep -q "^tcp_bbr$" /etc/modules 2>/dev/null; then
            echo "tcp_bbr" | sudo tee -a /etc/modules >/dev/null
            print_success "BBR module added to boot configuration"
        fi
    else
        print_success "BBR module already loaded"
    fi
    
    echo -e "\n${BOLD}Step 3/5: Updating sysctl configuration...${NC}"
    
    # Update or add BBR settings
    local settings_updated=0
    
    # Handle net.core.default_qdisc
    if grep -q "^net.core.default_qdisc=" /etc/sysctl.conf 2>/dev/null; then
        sudo sed -i 's/^net.core.default_qdisc=.*/net.core.default_qdisc=fq/' /etc/sysctl.conf
        print_info "Updated existing qdisc setting"
    else
        echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.conf >/dev/null
        print_info "Added qdisc setting"
    fi
    
    # Handle net.ipv4.tcp_congestion_control
    if grep -q "^net.ipv4.tcp_congestion_control=" /etc/sysctl.conf 2>/dev/null; then
        sudo sed -i 's/^net.ipv4.tcp_congestion_control=.*/net.ipv4.tcp_congestion_control=bbr/' /etc/sysctl.conf
        print_info "Updated existing congestion control setting"
    else
        echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.conf >/dev/null
        print_info "Added congestion control setting"
    fi
    
    print_success "Configuration file updated"
    
    echo -e "\n${BOLD}Step 4/5: Applying new settings...${NC}"
    if sudo sysctl -p >/dev/null 2>&1; then
        print_success "Settings applied successfully"
    else
        print_warning "Some settings may not have applied correctly"
    fi
    
    echo -e "\n${BOLD}Step 5/5: Verifying installation...${NC}"
    local new_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    local new_qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null)
    
    if [[ "$new_cc" == "bbr" ]]; then
        print_success "BBR is now active! ($new_cc)"
        if [[ "$new_qdisc" == "fq" ]]; then
            print_success "FQ queue discipline is active! ($new_qdisc)"
        else
            print_warning "Queue discipline is $new_qdisc (expected: fq)"
        fi
        
        echo -e "\n${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}${BOLD}║         BBR has been successfully enabled! 🎉            ║${NC}"
        echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    else
        print_error "Failed to enable BBR (still using $new_cc)"
        echo -e "${YELLOW}You can restore the backup with:${NC}"
        echo -e "${BOLD}sudo cp $backup_file /etc/sysctl.conf && sudo sysctl -p${NC}"
    fi
}

disable_bbr() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}              Disable BBR                                 ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    local current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    
    if [[ "$current_cc" != "bbr" ]] && [[ "$current_cc" != "bbr2" ]]; then
        print_info "BBR is not currently enabled (using $current_cc)"
        return 0
    fi
    
    echo -e "${YELLOW}${BOLD}This will disable BBR and revert to Cubic (default).${NC}\n"
    read -p "$(echo -e ${BOLD}Continue? \(y/N\): ${NC})" -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Operation cancelled"
        return 1
    fi
    
    # Backup current configuration
    sudo cp /etc/sysctl.conf "/etc/sysctl.conf.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Change to cubic
    sudo sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1
    sudo sysctl -w net.core.default_qdisc=pfifo_fast >/dev/null 2>&1
    
    # Update configuration file
    sudo sed -i 's/^net.ipv4.tcp_congestion_control=.*/net.ipv4.tcp_congestion_control=cubic/' /etc/sysctl.conf
    sudo sed -i 's/^net.core.default_qdisc=.*/net.core.default_qdisc=pfifo_fast/' /etc/sysctl.conf
    
    # Apply settings
    sudo sysctl -p >/dev/null 2>&1
    
    local new_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    if [[ "$new_cc" == "cubic" ]]; then
        print_success "BBR has been disabled. Now using: $new_cc"
    else
        print_error "Failed to disable BBR"
    fi
}

# DNS Functions
check_dns_status() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}              DNS Configuration Status                    ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${BOLD}Current DNS Servers:${NC}"
    if [ -f /etc/resolv.conf ]; then
        local dns_count=0
        while IFS= read -r line; do
            if [[ "$line" =~ ^nameserver ]]; then
                local server=$(echo "$line" | awk '{print $2}')
                ((dns_count++))
                echo -e "  ${BOLD}$dns_count.${NC} ${YELLOW}$server${NC}"
                
                # Identify known DNS providers
                case "$server" in
                    "1.1.1.1"|"1.0.0.1") echo -e "     ${DIM}(Cloudflare DNS)${NC}" ;;
                    "8.8.8.8"|"8.8.4.4") echo -e "     ${DIM}(Google DNS)${NC}" ;;
                    "9.9.9.9"|"149.112.112.112") echo -e "     ${DIM}(Quad9 DNS)${NC}" ;;
                    "208.67.222.222"|"208.67.220.220") echo -e "     ${DIM}(OpenDNS)${NC}" ;;
                    *) echo -e "     ${DIM}(Custom/ISP DNS)${NC}" ;;
                esac
            fi
        done < /etc/resolv.conf
        
        if [ $dns_count -eq 0 ]; then
            print_warning "No DNS servers configured in /etc/resolv.conf"
        fi
    else
        print_error "/etc/resolv.conf not found"
    fi
    
    # Check if using systemd-resolved
    echo -e "\n${BOLD}DNS Management:${NC}"
    if systemctl is-active systemd-resolved >/dev/null 2>&1; then
        print_info "Using systemd-resolved"
        if command -v resolvectl &> /dev/null; then
            echo -e "\n${BOLD}Systemd-resolved Status:${NC}"
            resolvectl status 2>/dev/null | grep -E "DNS Servers|DNS Domain" | head -5 | sed 's/^/  /'
        fi
    else
        print_info "Using traditional /etc/resolv.conf"
    fi
    
    # Test DNS resolution
    echo -e "\n${BOLD}DNS Resolution Test:${NC}"
    local test_domains=("google.com" "cloudflare.com" "github.com")
    local success_count=0
    
    for domain in "${test_domains[@]}"; do
        echo -n "  Testing $domain... "
        if getent hosts "$domain" >/dev/null 2>&1; then
            local ip=$(getent hosts "$domain" 2>/dev/null | head -1 | awk '{print $1}')
            echo -e "${GREEN}✓${NC} ($ip)"
            ((success_count++))
        else
            echo -e "${RED}✗${NC}"
        fi
    done
    
    echo -e "\n${BOLD}Overall DNS Status:${NC}"
    if [ $success_count -eq ${#test_domains[@]} ]; then
        print_success "DNS resolution is working perfectly!"
    elif [ $success_count -gt 0 ]; then
        print_warning "DNS is partially working ($success_count/${#test_domains[@]} successful)"
    else
        print_error "DNS resolution is not working!"
    fi
}

test_dns_resolution() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}              DNS Resolution Testing                      ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    read -p "$(echo -e ${BOLD}Enter domain to test \(default: google.com\): ${NC})" domain
    domain=${domain:-google.com}
    
    echo -e "\n${BOLD}Testing DNS resolution for: ${YELLOW}$domain${NC}\n"
    
    # Test with system resolver
    echo -e "${BOLD}1. System DNS Resolution:${NC}"
    local result=$(getent hosts "$domain" 2>/dev/null)
    if [ -n "$result" ]; then
        echo "$result" | while IFS= read -r line; do
            local ip=$(echo "$line" | awk '{print $1}')
            local type="IPv4"
            [[ "$ip" == *":"* ]] && type="IPv6"
            echo -e "   ${GREEN}✓${NC} $type: ${YELLOW}$ip${NC}"
        done
    else
        print_error "   Failed to resolve using system DNS"
    fi
    
    # Test with different DNS servers
    echo -e "\n${BOLD}2. Testing with Public DNS Servers:${NC}"
    
    # Check if we have dig or nslookup
    local dns_tool=""
    if command -v dig &> /dev/null; then
        dns_tool="dig"
    elif command -v nslookup &> /dev/null; then
        dns_tool="nslookup"
    fi
    
    if [ -n "$dns_tool" ]; then
        local dns_servers=(
            "1.1.1.1:Cloudflare"
            "8.8.8.8:Google"
            "9.9.9.9:Quad9"
            "208.67.222.222:OpenDNS"
        )
        
        for server_info in "${dns_servers[@]}"; do
            local server="${server_info%%:*}"
            local name="${server_info##*:}"
            
            echo -n "   ${BOLD}$name ($server):${NC} "
            
            if [ "$dns_tool" = "dig" ]; then
                if result=$(dig +short "$domain" @"$server" 2>/dev/null | head -1); then
                    if [ -n "$result" ]; then
                        echo -e "${GREEN}✓${NC} $result"
                    else
                        echo -e "${RED}✗${NC} No result"
                    fi
                else
                    echo -e "${RED}✗${NC} Failed"
                fi
            else
                if result=$(nslookup "$domain" "$server" 2>/dev/null | grep -A1 "Name:" | grep "Address:" | tail -1 | awk '{print $2}'); then
                    if [ -n "$result" ]; then
                        echo -e "${GREEN}✓${NC} $result"
                    else
                        echo -e "${RED}✗${NC} No result"
                    fi
                else
                    echo -e "${RED}✗${NC} Failed"
                fi
            fi
        done
    else
        print_warning "   Install dig or nslookup for detailed DNS server tests"
        
        # Fallback to ping test
        echo -e "\n${BOLD}3. Connectivity Test:${NC}"
        echo -n "   Ping test for $domain: "
        if ping -c 1 -W 2 "$domain" &>/dev/null; then
            local ip=$(ping -c 1 "$domain" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
            echo -e "${GREEN}✓${NC} Reachable at $ip"
        else
            echo -e "${RED}✗${NC} Cannot reach"
        fi
    fi
    
    # DNS response time test
    echo -e "\n${BOLD}3. DNS Response Time:${NC}"
    if command -v dig &> /dev/null; then
        local query_time=$(dig "$domain" | grep "Query time:" | awk '{print $4}')
        if [ -n "$query_time" ]; then
            echo -e "   Query time: ${YELLOW}${query_time} ms${NC}"
            if [ "$query_time" -lt 50 ]; then
                print_success "   Excellent response time!"
            elif [ "$query_time" -lt 100 ]; then
                print_info "   Good response time"
            else
                print_warning "   Slow response time"
            fi
        fi
    fi
}

change_dns_servers() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}              DNS Server Configuration                    ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    # Check if using systemd-resolved
    if systemctl is-active systemd-resolved >/dev/null 2>&1; then
        print_warning "System is using systemd-resolved"
        echo -e "${YELLOW}Changes to /etc/resolv.conf may be overwritten.${NC}"
        echo -e "${YELLOW}Consider using systemd-resolved configuration instead.${NC}\n"
    fi
    
    echo -e "${BOLD}Select DNS Provider:${NC}\n"
    echo -e "${BOLD}  1)${NC} ${CYAN}Cloudflare${NC} (1.1.1.1, 1.0.0.1)"
    echo -e "     ${DIM}Privacy-focused, fastest${NC}"
    echo -e "${BOLD}  2)${NC} ${CYAN}Google${NC} (8.8.8.8, 8.8.4.4)"
    echo -e "     ${DIM}Reliable, widely used${NC}"
    echo -e "${BOLD}  3)${NC} ${CYAN}Quad9${NC} (9.9.9.9, 149.112.112.112)"
    echo -e "     ${DIM}Security-focused, blocks malware${NC}"
    echo -e "${BOLD}  4)${NC} ${CYAN}OpenDNS${NC} (208.67.222.222, 208.67.220.220)"
    echo -e "     ${DIM}Content filtering available${NC}"
    echo -e "${BOLD}  5)${NC} ${CYAN}AdGuard${NC} (94.140.14.14, 94.140.15.15)"
    echo -e "     ${DIM}Ad-blocking DNS${NC}"
    echo -e "${BOLD}  6)${NC} ${CYAN}Custom DNS servers${NC}"
    echo -e "${BOLD}  7)${NC} ${CYAN}View current configuration${NC}"
    echo -e "${BOLD}  0)${NC} Cancel\n"
    
    read -p "$(echo -e ${BOLD}Select option \(0-7\): ${NC})" dns_choice
    
    local dns1="" dns2="" provider=""
    
    case $dns_choice in
        1) dns1="1.1.1.1"; dns2="1.0.0.1"; provider="Cloudflare" ;;
        2) dns1="8.8.8.8"; dns2="8.8.4.4"; provider="Google" ;;
        3) dns1="9.9.9.9"; dns2="149.112.112.112"; provider="Quad9" ;;
        4) dns1="208.67.222.222"; dns2="208.67.220.220"; provider="OpenDNS" ;;
        5) dns1="94.140.14.14"; dns2="94.140.15.15"; provider="AdGuard" ;;
        6) 
            read -p "$(echo -e ${BOLD}Enter primary DNS server IP: ${NC})" dns1
            read -p "$(echo -e ${BOLD}Enter secondary DNS server IP \(optional\): ${NC})" dns2
            provider="Custom"
            
            # Validate IP addresses
            if ! [[ "$dns1" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                print_error "Invalid IP address format"
                return 1
            fi
            ;;
        7)
            cat /etc/resolv.conf
            return 0
            ;;
        0) 
            print_info "Operation cancelled"
            return 0
            ;;
        *) 
            print_error "Invalid option"
            return 1
            ;;
    esac
    
    if [ -n "$dns1" ]; then
        echo -e "\n${BOLD}Selected DNS Provider: ${YELLOW}$provider${NC}"
        echo -e "${BOLD}Primary DNS: ${YELLOW}$dns1${NC}"
        [ -n "$dns2" ] && echo -e "${BOLD}Secondary DNS: ${YELLOW}$dns2${NC}"
        
        echo -e "\n${YELLOW}This will replace your current DNS configuration.${NC}"
        read -p "$(echo -e ${BOLD}Continue? \(y/N\): ${NC})" -n 1 -r
        echo
        
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_warning "Operation cancelled"
            return 1
        fi
        
        # Backup current configuration
        echo -e "\n${BOLD}Creating backup...${NC}"
        local backup_file="/etc/resolv.conf.backup.$(date +%Y%m%d_%H%M%S)"
        sudo cp /etc/resolv.conf "$backup_file"
        print_success "Backup saved to: $backup_file"
        
        # Apply new DNS servers
        echo -e "\n${BOLD}Applying new DNS configuration...${NC}"
        
        # Check if resolv.conf is immutable
        if lsattr /etc/resolv.conf 2>/dev/null | grep -q 'i'; then
            print_warning "/etc/resolv.conf is immutable, removing protection..."
            sudo chattr -i /etc/resolv.conf
        fi
        
        # Write new configuration
        {
            echo "# DNS Configuration - $(date)"
            echo "# Provider: $provider"
            echo "nameserver $dns1"
            [ -n "$dns2" ] && echo "nameserver $dns2"
            echo "options edns0 trust-ad"
        } | sudo tee /etc/resolv.conf > /dev/null
        
        print_success "DNS servers updated!"
        
        # Test new configuration
        echo -e "\n${BOLD}Testing new DNS configuration...${NC}"
        local test_success=0
        
        for domain in google.com cloudflare.com; do
            echo -n "  Testing $domain... "
            if getent hosts "$domain" >/dev/null 2>&1; then
                echo -e "${GREEN}✓${NC}"
                ((test_success++))
            else
                echo -e "${RED}✗${NC}"
            fi
        done
        
        if [ $test_success -gt 0 ]; then
            print_success "DNS is working with new servers!"
            
            # Make configuration persistent
            echo -e "\n${BOLD}Make configuration persistent?${NC}"
            echo -e "${YELLOW}This will prevent DHCP from overwriting DNS settings${NC}"
            read -p "$(echo -e ${BOLD}Make persistent? \(y/N\): ${NC})" -n 1 -r
            echo
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo chattr +i /etc/resolv.conf 2>/dev/null
                print_success "DNS configuration locked (immutable)"
                echo -e "${DIM}To unlock later: sudo chattr -i /etc/resolv.conf${NC}"
            fi
        else
            print_error "DNS resolution failed with new servers!"
            echo -e "${YELLOW}Reverting to previous configuration...${NC}"
            sudo cp "$backup_file" /etc/resolv.conf
            print_success "Previous configuration restored"
        fi
    fi
}

flush_dns_cache() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}              Flush DNS Cache                             ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    local flushed=false
    
    # systemd-resolved
    if systemctl is-active systemd-resolved >/dev/null 2>&1; then
        echo -e "${BOLD}Flushing systemd-resolved cache...${NC}"
        if sudo systemd-resolve --flush-caches 2>/dev/null || sudo resolvectl flush-caches 2>/dev/null; then
            print_success "systemd-resolved cache flushed"
            flushed=true
        fi
    fi
    
    # nscd
    if systemctl is-active nscd >/dev/null 2>&1; then
        echo -e "${BOLD}Restarting nscd service...${NC}"
        if sudo systemctl restart nscd; then
            print_success "nscd cache flushed"
            flushed=true
        fi
    fi
    
    # dnsmasq
    if systemctl is-active dnsmasq >/dev/null 2>&1; then
        echo -e "${BOLD}Restarting dnsmasq service...${NC}"
        if sudo systemctl restart dnsmasq; then
            print_success "dnsmasq cache flushed"
            flushed=true
        fi
    fi
    
    if [ "$flushed" = false ]; then
        print_info "No DNS caching service detected"
        echo -e "${YELLOW}Your system may not be using DNS caching${NC}"
    else
        echo -e "\n${GREEN}${BOLD}DNS cache has been successfully flushed!${NC}"
    fi
}

# Main menu
network_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}${BOLD}                 🌐 Network Tools                         ${NC}${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
        
        echo -e "${GREEN}${BOLD}TCP Congestion Control (BBR):${NC}"
        echo -e "${YELLOW}  1)${NC} 🔍 Check BBR status"
        echo -e "${YELLOW}  2)${NC} ⚡ Enable BBR optimization"
        echo -e "${YELLOW}  3)${NC} 🔄 Disable BBR (revert to Cubic)"
        
        echo -e "\n${GREEN}${BOLD}DNS Management:${NC}"
        echo -e "${YELLOW}  4)${NC} 🔍 Check DNS configuration"
        echo -e "${YELLOW}  5)${NC} 🌐 Test DNS resolution"
        echo -e "${YELLOW}  6)${NC} ⚡ Change DNS servers"
        echo -e "${YELLOW}  7)${NC} 🗑️  Flush DNS cache"
        
        echo -e "\n${GREEN}${BOLD}System Information:${NC}"
        echo -e "${YELLOW}  8)${NC} ℹ️  Network information"
        
        echo -e "\n${RED}  0)${NC} ↩️  Exit\n"
        
        echo -e "${DIM}System: $(uname -r) | Current time: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
        echo
        
        read -p "$(echo -e ${BOLD}Select option \(0-8\): ${NC})" choice
        
        case $choice in
            1)
                clear
                print_large "🔍 BBR Status Check"
                check_bbr_status
                echo -e "\n${YELLOW}${BOLD}Press Enter to continue...${NC}"
                read
                ;;
                
            2)
                clear
                print_large "⚡ Enable BBR Optimization"
                enable_bbr
                echo -e "\n${YELLOW}${BOLD}Press Enter to continue...${NC}"
                read
                ;;
                
            3)
                clear
                print_large "🔄 Disable BBR"
                disable_bbr
                echo -e "\n${YELLOW}${BOLD}Press Enter to continue...${NC}"
                read
                ;;
                
            4)
                clear
                print_large "🔍 DNS Configuration Status"
                check_dns_status
                echo -e "\n${YELLOW}${BOLD}Press Enter to continue...${NC}"
                read
                ;;
                
            5)
                clear
                print_large "🌐 DNS Resolution Test"
                test_dns_resolution
                echo -e "\n${YELLOW}${BOLD}Press Enter to continue...${NC}"
                read
                ;;
                
            6)
                clear
                print_large "⚡ Change DNS Servers"
                change_dns_servers
                echo -e "\n${YELLOW}${BOLD}Press Enter to continue...${NC}"
                read
                ;;
                
            7)
                clear
                print_large "🗑️ Flush DNS Cache"
                flush_dns_cache
                echo -e "\n${YELLOW}${BOLD}Press Enter to continue...${NC}"
                read
                ;;
                
            8)
                clear
                print_large "ℹ️ Network Information"
                echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
                echo -e "${CYAN}║${NC}${BOLD}              System Network Information                  ${NC}${CYAN}║${NC}"
                echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
                
                echo -e "${BOLD}Hostname:${NC} ${YELLOW}$(hostname -f 2>/dev/null || hostname)${NC}"
                echo -e "${BOLD}Kernel:${NC} ${YELLOW}$(uname -r)${NC}"
                echo -e "${BOLD}OS:${NC} ${YELLOW}$(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)${NC}\n"
                
                echo -e "${BOLD}Network Interfaces:${NC}"
                ip -br addr | while IFS= read -r line; do
                    echo -e "  ${YELLOW}$line${NC}"
                done
                
                echo -e "\n${BOLD}Default Gateway:${NC}"
                ip route | grep default | head -1 | sed 's/^/  /'
                
                echo -e "\n${BOLD}Public IP:${NC}"
                if command -v curl &> /dev/null; then
                    local public_ip=$(curl -s -4 ifconfig.me 2>/dev/null)
                    [ -n "$public_ip" ] && echo -e "  IPv4: ${YELLOW}$public_ip${NC}"
                    
                    local public_ip6=$(curl -s -6 ifconfig.me 2>/dev/null)
                    [ -n "$public_ip6" ] && echo -e "  IPv6: ${YELLOW}$public_ip6${NC}"
                else
                    echo -e "  ${DIM}Install curl to check public IP${NC}"
                fi
                
                echo -e "\n${YELLOW}${BOLD}Press Enter to continue...${NC}"
                read
                ;;
                
            0)
                echo -e "\n${GREEN}${BOLD}Thank you for using Network Tools!${NC}\n"
                exit 0
                ;;
                
            *)
                print_error "Invalid option. Please try again."
                sleep 1
                ;;
        esac
    done
}

# Check if running with sufficient privileges for certain operations
if ! check_root; then
    echo -e "${YELLOW}${BOLD}Note: Some operations may require sudo privileges${NC}"
fi

# Start the menu
network_menu

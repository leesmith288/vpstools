#!/bin/bash

# Caddy Manager - Part of VPS Tools Suite
# Host as: caddy-manager.sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Function to check and ensure Caddy is held
ensure_caddy_held() {
    if apt-mark showhold | grep -q "^caddy$"; then
        echo -e "${GREEN}✓ Caddy package is held - Protected from system updates${NC}"
        echo -e "${DIM}  Your custom Caddy with Cloudflare plugin will survive reboots and updates${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Caddy package is NOT held - Holding it now...${NC}"
        if sudo apt-mark hold caddy 2>/dev/null; then
            echo -e "${GREEN}✓ Successfully held Caddy package${NC}"
            echo -e "${DIM}  Your custom Caddy is now protected from system updates${NC}"
        else
            echo -e "${YELLOW}Note: Could not hold package (might not be installed via apt)${NC}"
        fi
        sleep 2
        return 0
    fi
}

# Function to check and install tree if needed
ensure_tree_installed() {
    if ! command -v tree &> /dev/null; then
        echo -e "${YELLOW}Tree command not found. Installing...${NC}"
        if sudo apt update && sudo apt install -y tree; then
            echo -e "${GREEN}✓ Tree installed successfully${NC}"
        else
            echo -e "${RED}✗ Failed to install tree${NC}"
            return 1
        fi
    fi
    return 0
}

# Function to manage certificates
manage_certificates() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}              🔐 Certificate Management                    ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    # Ensure tree is installed
    if ! ensure_tree_installed; then
        echo -e "${RED}Cannot proceed without tree command${NC}"
        echo -e "\n${YELLOW}Press Enter to return...${NC}"
        read
        return
    fi
    
    CERT_DIR="/var/lib/caddy/.local/share/caddy/certificates"
    CADDYFILE="/etc/caddy/Caddyfile"

    # Minimal, robust hostname normalizer (lowercase, remove wildcard, keep only valid ASCII hostname chars)
    normalize_host() {
        local s="$1"
        # Lowercase
        s=$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')
        # Remove ASCII whitespace (incl. CR/LF/TAB)
        s=$(printf '%s' "$s" | tr -d '[:space:]')
        # Drop leading "*." wildcard if present
        if [[ "$s" == \*.* ]]; then s="${s#*.}"; fi
        # Strip any trailing dot
        s="${s%.}"
        # Keep only ASCII hostname chars to kill any hidden non-ASCII bytes
        s=$(printf '%s' "$s" | LC_ALL=C tr -cd '[:alnum:].-')
        printf '%s' "$s"
    }
    
    # Check with sudo permission
    if ! sudo test -d "$CERT_DIR"; then
        echo -e "${YELLOW}Certificate directory not accessible at: $CERT_DIR${NC}"
        echo -e "${DIM}Checking with elevated permissions...${NC}"
        
        if sudo test -d "/var/lib/caddy/.local/share/caddy"; then
            echo -e "${GREEN}Parent directory exists, checking for certificates...${NC}"
            sudo ls -la "/var/lib/caddy/.local/share/caddy/" 2>/dev/null
        fi
        
        echo -e "\n${YELLOW}Press Enter to return...${NC}"
        read
        return
    fi
    
    while true; do
        clear
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}${BOLD}              🔐 Certificate Management                    ${NC}${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
        
        echo -e "${GREEN}${BOLD}Options:${NC}"
        echo -e "${YELLOW}  1)${NC} 📂 View certificate tree structure"
        echo -e "${YELLOW}  2)${NC} 📋 List all domains with certificates"
        echo -e "${YELLOW}  3)${NC} 🔍 Show certificate details for a domain"
        echo -e "${YELLOW}  4)${NC} 🗑️  Clean up abandoned certificates"
        echo -e "\n${RED}  0)${NC} ↩️  Back to main menu\n"
        
        read -p "$(echo -e ${BOLD}Select option: ${NC})" cert_choice
        
        case $cert_choice in
            1) # View certificate tree
                echo -e "\n${CYAN}Certificate Directory Structure:${NC}\n"
                sudo tree "$CERT_DIR" -I '.git|__pycache__'
                echo -e "\n${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
                
            2) # List all domains
                echo -e "\n${CYAN}Domains with certificates:${NC}\n"
                for acme_dir in $(sudo find "$CERT_DIR" -maxdepth 1 -type d); do
                    if [ "$acme_dir" != "$CERT_DIR" ]; then
                        echo -e "${GREEN}ACME Provider: $(basename "$acme_dir")${NC}"
                        for domain_dir in $(sudo find "$acme_dir" -maxdepth 1 -type d); do
                            if [ "$domain_dir" != "$acme_dir" ]; then
                                domain_name=$(basename "$domain_dir")
                                domain_name=$(normalize_host "$domain_name")
                                echo -e "  ${YELLOW}→${NC} $domain_name"
                                if sudo test -f "$domain_dir/${domain_name}.crt"; then
                                    echo -e "    ${DIM}✓ Certificate found${NC}"
                                fi
                            fi
                        done
                    fi
                done
                echo -e "\n${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
                
            3) # Show certificate details
                echo -e "\n${CYAN}Enter domain name to inspect:${NC}"
                read -p "Domain: " domain_inspect
                domain_inspect=$(normalize_host "$domain_inspect")
                
                if [ -z "$domain_inspect" ]; then
                    echo -e "${RED}No domain entered${NC}"
                    sleep 2
                    continue
                fi
                
                found=false
                for acme_dir in $(sudo find "$CERT_DIR" -maxdepth 1 -type d); do
                    if [ "$acme_dir" != "$CERT_DIR" ]; then
                        domain_path="$acme_dir/$domain_inspect"
                        if sudo test -d "$domain_path"; then
                            found=true
                            echo -e "\n${GREEN}Certificate files for $domain_inspect:${NC}\n"
                            sudo ls -lah "$domain_path"
                            
                            cert_file="$domain_path/${domain_inspect}.crt"
                            if sudo test -f "$cert_file"; then
                                echo -e "\n${CYAN}Certificate details:${NC}"
                                sudo openssl x509 -in "$cert_file" -noout -text | grep -E "Subject:|Validity|Not Before:|Not After:" | head -10
                                echo -e "\n${CYAN}Certificate expiry:${NC}"
                                sudo openssl x509 -in "$cert_file" -noout -enddate
                            fi
                            
                            echo -e "\n${CYAN}Full path:${NC} $domain_path"
                            break
                        fi
                    fi
                done
                
                if [ "$found" = false ]; then
                    echo -e "${YELLOW}No certificates found for domain: $domain_inspect${NC}"
                fi
                
                echo -e "\n${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
                
            4) # Clean up abandoned certificates
                echo -e "\n${CYAN}Analyzing certificates and Caddyfile...${NC}\n"
                
                echo -e "${DIM}Reading domains from Caddyfile...${NC}"
                active_domains=()
                if [ -f "$CADDYFILE" ]; then
                    while IFS= read -r line; do
                        line=$(echo "$line" | sed 's/#.*//' | sed 's/^[ \t]*//;s/[ \t]*$//')
                        [ -z "$line" ] && continue
                        
                        if [[ "$line" =~ ^([a-zA-Z0-9][a-zA-Z0-9\.\-]*\.[a-zA-Z]{2,})[[:space:]]*\{ ]]; then
                            domain="${BASH_REMATCH[1]}"
                            domain=$(normalize_host "$domain")
                            active_domains+=("$domain")
                        elif [[ "$line" =~ ^https?://([a-zA-Z0-9][a-zA-Z0-9\.\-]*\.[a-zA-Z]{2,}) ]]; then
                            domain="${BASH_REMATCH[1]}"
                            domain=$(normalize_host "$domain")
                            active_domains+=("$domain")
                        elif [[ "$line" =~ ^([a-zA-Z0-9][a-zA-Z0-9\.\-]*\.[a-zA-Z]{2,}):[0-9]+ ]]; then
                            domain="${BASH_REMATCH[1]}"
                            domain=$(normalize_host "$domain")
                            active_domains+=("$domain")
                        fi
                    done < <(sudo cat "$CADDYFILE")
                    
                    # Remove duplicates
                    active_domains=($(printf "%s\n" "${active_domains[@]}" | sort -u))
                    
                    echo -e "${GREEN}Found ${#active_domains[@]} active domains in Caddyfile${NC}"
                    if [ ${#active_domains[@]} -gt 0 ]; then
                        echo -e "${DIM}Active domains:${NC}"
                        for dom in "${active_domains[@]}"; do
                            echo -e "${DIM}  - '$dom'${NC}"
                        done
                        echo
                    fi
                else
                    echo -e "${RED}Caddyfile not found at $CADDYFILE${NC}"
                fi
                
                echo -e "${DIM}Scanning certificate directories...${NC}"
                cert_domains=()
                cert_paths=()
                
                for acme_dir in $(sudo find "$CERT_DIR" -maxdepth 1 -type d); do
                    if [ "$acme_dir" != "$CERT_DIR" ]; then
                        for domain_dir in $(sudo find "$acme_dir" -maxdepth 1 -type d); do
                            if [ "$domain_dir" != "$acme_dir" ]; then
                                domain_name=$(basename "$domain_dir")
                                domain_name=$(normalize_host "$domain_name")
                                cert_domains+=("$domain_name")
                                cert_paths+=("$domain_dir")
                            fi
                        done
                    fi
                done
                
                echo -e "${GREEN}Found ${#cert_domains[@]} domains with certificates${NC}"
                echo -e "${DIM}Certificate domains:${NC}"
                for cert_dom in "${cert_domains[@]}"; do
                    echo -e "${DIM}  - '$cert_dom'${NC}"
                done
                echo
                
                abandoned_domains=()
                abandoned_paths=()
                
                for i in "${!cert_domains[@]}"; do
                    domain="${cert_domains[$i]}"
                    path="${cert_paths[$i]}"
                    is_active=false
                    
                    echo -e "${DIM}Checking if '$domain' is active...${NC}"
                    
                    for active_domain in "${active_domains[@]}"; do
                        if [[ "$domain" == "$active_domain" ]]; then
                            echo -e "${DIM}  ✓ Found exact match with active domain '$active_domain'${NC}"
                            is_active=true
                            break
                        elif [[ "$domain" == "www.${active_domain}" ]]; then
                            echo -e "${DIM}  ✓ Found www variant match with active domain '$active_domain'${NC}"
                            is_active=true
                            break
                        elif [[ "$active_domain" == "www.${domain}" ]]; then
                            echo -e "${DIM}  ✓ Found non-www match with active domain '$active_domain'${NC}"
                            is_active=true
                            break
                        fi
                    done
                    
                    if [ "$is_active" = true ]; then
                        echo -e "${DIM}  → Domain '$domain' is ACTIVE${NC}"
                    else
                        echo -e "${DIM}  → Domain '$domain' is ABANDONED${NC}"
                        abandoned_domains+=("$domain")
                        abandoned_paths+=("$path")
                    fi
                done
                
                echo
                
                if [ ${#abandoned_domains[@]} -eq 0 ]; then
                    echo -e "${GREEN}✓ No abandoned certificates found!${NC}"
                    echo -e "${DIM}All certificate domains are active in the Caddyfile${NC}"
                else
                    echo -e "${YELLOW}⚠️  Found ${#abandoned_domains[@]} abandoned certificate(s):${NC}\n"
                    
                    for i in "${!abandoned_domains[@]}"; do
                        num=$((i + 1))
                        echo -e "  ${RED}${num})${NC} ${abandoned_domains[$i]}"
                    done
                    
                    echo -e "\n${CYAN}What would you like to do?${NC}"
                    echo -e "${YELLOW}  1)${NC} Delete all abandoned certificates"
                    echo -e "${YELLOW}  2)${NC} Delete specific certificate(s)"
                    echo -e "${YELLOW}  0)${NC} Cancel\n"
                    
                    read -p "$(echo -e ${BOLD}Select option: ${NC})" cleanup_choice
                    
                    case $cleanup_choice in
                        1) # Delete all
                            echo -e "\n${RED}⚠️  This will delete ALL ${#abandoned_domains[@]} abandoned certificate(s)${NC}"
                            echo -e "${CYAN}Domains to be deleted:${NC}"
                            for domain in "${abandoned_domains[@]}"; do
                                echo -e "  ${YELLOW}→${NC} $domain"
                            done
                            
                            echo -e "\n${BOLD}Are you sure? (y/N):${NC} "
                            read -n 1 -r confirm_all
                            echo
                            
                            if [[ $confirm_all =~ ^[Yy]$ ]]; then
                                deleted_count=0
                                failed_count=0
                                
                                for i in "${!abandoned_paths[@]}"; do
                                    echo -e "${CYAN}Deleting ${abandoned_domains[$i]}...${NC}"
                                    if sudo rm -rf "${abandoned_paths[$i]}"; then
                                        echo -e "${GREEN}  ✓ Deleted${NC}"
                                        ((deleted_count++))
                                    else
                                        echo -e "${RED}  ✗ Failed${NC}"
                                        ((failed_count++))
                                    fi
                                done
                                
                                echo -e "\n${GREEN}Deleted $deleted_count certificate(s)${NC}"
                                if [ $failed_count -gt 0 ]; then
                                    echo -e "${RED}Failed to delete $failed_count certificate(s)${NC}"
                                fi
                            else
                                echo -e "${YELLOW}Deletion cancelled${NC}"
                            fi
                            ;;
                            
                        2) # Delete specific
                            echo -e "\n${CYAN}Enter the numbers of certificates to delete (space-separated):${NC}"
                            echo -e "${DIM}Example: 1 3 4${NC}"
                            read -p "Numbers: " selected_nums
                            
                            if [ -z "$selected_nums" ]; then
                                echo -e "${YELLOW}No selection made${NC}"
                            else
                                to_delete=()
                                for num in $selected_nums; do
                                    if [[ "$num" =~ ^[0-9]+$ ]] && [ $num -ge 1 ] && [ $num -le ${#abandoned_domains[@]} ]; then
                                        index=$((num - 1))
                                        to_delete+=($index)
                                    else
                                        echo -e "${RED}Invalid number: $num${NC}"
                                    fi
                                done
                                
                                if [ ${#to_delete[@]} -gt 0 ]; then
                                    echo -e "\n${YELLOW}Will delete:${NC}"
                                    for idx in "${to_delete[@]}"; do
                                        echo -e "  ${YELLOW}→${NC} ${abandoned_domains[$idx]}"
                                    done
                                    
                                    echo -e "\n${BOLD}Confirm deletion? (y/N):${NC} "
                                    read -n 1 -r confirm_selected
                                    echo
                                    
                                    if [[ $confirm_selected =~ ^[Yy]$ ]]; then
                                        for idx in "${to_delete[@]}"; do
                                            echo -e "${CYAN}Deleting ${abandoned_domains[$idx]}...${NC}"
                                            if sudo rm -rf "${abandoned_paths[$idx]}"; then
                                                echo -e "${GREEN}  ✓ Deleted${NC}"
                                            else
                                                echo -e "${RED}  ✗ Failed${NC}"
                                            fi
                                        done
                                    else
                                        echo -e "${YELLOW}Deletion cancelled${NC}"
                                    fi
                                fi
                            fi
                            ;;
                            
                        0|*)
                            echo -e "${YELLOW}Cleanup cancelled${NC}"
                            ;;
                    esac
                fi
                
                echo -e "\n${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
                
            0) # Back to main menu
                return
                ;;
                
            *)
                echo -e "${RED}Invalid option${NC}"
                sleep 1
                ;;
        esac
    done
}

# Function to update Caddy with Cloudflare plugin
update_caddy_cloudflare() {
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}         Update Caddy with Cloudflare Plugin              ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    # Detect architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "aarch64" ]; then
        CADDY_ARCH="arm64"
    elif [ "$ARCH" = "x86_64" ]; then
        CADDY_ARCH="amd64"
    else
        echo -e "${RED}Unsupported architecture: $ARCH${NC}"
        return 1
    fi
    
    echo -e "${CYAN}Detected architecture: ${BOLD}$CADDY_ARCH${NC}"
    echo -e "${YELLOW}This will download and install the latest Caddy with Cloudflare DNS plugin${NC}\n"
    
    read -p "Continue with update? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Update cancelled${NC}"
        return 0
    fi
    
    # Check if package is held and temporarily unhold it
    WAS_HELD=false
    if apt-mark showhold | grep -q "^caddy$"; then
        WAS_HELD=true
        echo -e "${CYAN}Temporarily unholding Caddy package for update...${NC}"
        sudo apt-mark unhold caddy
    fi
    
    # Create temp directory
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    echo -e "\n${CYAN}Downloading Caddy with Cloudflare plugin...${NC}"
    DOWNLOAD_URL="https://caddyserver.com/api/download?os=linux&arch=${CADDY_ARCH}&p=github.com%2Fcaddy-dns%2Fcloudflare"
    
    if wget -q --show-progress "$DOWNLOAD_URL" -O caddy; then
        echo -e "${GREEN}✓ Download complete${NC}"
        
        # Make executable
        chmod +x caddy
        
        # Verify it has the plugin
        if ./caddy list-modules | grep -q cloudflare; then
            echo -e "${GREEN}✓ Cloudflare plugin verified${NC}"
            
            # Backup current caddy
            if [ -f /usr/bin/caddy ]; then
                echo -e "${CYAN}Backing up current Caddy...${NC}"
                sudo cp /usr/bin/caddy /usr/bin/caddy.backup.$(date +%Y%m%d_%H%M%S)
                echo -e "${DIM}  Backup saved to: /usr/bin/caddy.backup.$(date +%Y%m%d_%H%M%S)${NC}"
            fi
            
            # Stop Caddy
            echo -e "${CYAN}Stopping Caddy service...${NC}"
            sudo systemctl stop caddy
            
            # Install new binary
            echo -e "${CYAN}Installing new Caddy binary...${NC}"
            sudo mv caddy /usr/bin/caddy
            
            # Start Caddy
            echo -e "${CYAN}Starting Caddy service...${NC}"
            if sudo systemctl start caddy; then
                echo -e "${GREEN}✓ Caddy updated and started successfully!${NC}"
                
                # Show version
                echo -e "\n${CYAN}New Caddy version:${NC}"
                caddy version
                
                # Re-hold the package if it was held before
                if [ "$WAS_HELD" = true ]; then
                    echo -e "\n${CYAN}Re-holding Caddy package...${NC}"
                    sudo apt-mark hold caddy
                    echo -e "${GREEN}✓ Caddy package is held again${NC}"
                fi
            else
                echo -e "${RED}✗ Failed to start Caddy${NC}"
                echo -e "${YELLOW}Check logs with: sudo journalctl -u caddy -n 50${NC}"
                # Still re-hold if it was held before
                if [ "$WAS_HELD" = true ]; then
                    sudo apt-mark hold caddy
                fi
            fi
        else
            echo -e "${RED}✗ Downloaded binary doesn't have Cloudflare plugin${NC}"
            rm -f caddy
            # Re-hold if it was held before
            if [ "$WAS_HELD" = true ]; then
                sudo apt-mark hold caddy
            fi
        fi
    else
        echo -e "${RED}✗ Failed to download Caddy${NC}"
        # Re-hold if it was held before
        if [ "$WAS_HELD" = true ]; then
            sudo apt-mark hold caddy
        fi
    fi
    
    # Cleanup
    cd - > /dev/null
    rm -rf "$TMP_DIR"
    
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read
}

caddy_menu() {
    # First, ensure Caddy is held when starting the script
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}           Checking Caddy Protection Status               ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    ensure_caddy_held
    
    while true; do
        clear
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}${BOLD}                 🌐 Caddy Web Server Manager              ${NC}${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
        
        # Check Caddy status
        if systemctl is-active --quiet caddy 2>/dev/null; then
            echo -e "${GREEN}✓ Caddy Status: Running${NC}"
        else
            echo -e "${RED}✗ Caddy Status: Not Running${NC}"
        fi
        
        # Show protection status
        if apt-mark showhold | grep -q "^caddy$"; then
            echo -e "${GREEN}✓ Update Protection: Enabled${NC}"
        else
            echo -e "${YELLOW}⚠️  Update Protection: Disabled${NC}"
        fi
        
        echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        
        echo -e "${GREEN}${BOLD}Configuration:${NC}"
        echo -e "${YELLOW}  1)${NC} 📝 Edit Caddyfile"
        echo -e "${YELLOW}  2)${NC} 📋 Show current config"
        
        echo -e "\n${GREEN}${BOLD}Service Control:${NC}"
        echo -e "${YELLOW}  3)${NC} 🔁 Restart Caddy"
        echo -e "${YELLOW}  4)${NC} ⏹️  Stop Caddy"
        echo -e "${YELLOW}  5)${NC} ▶️  Start Caddy"
        
        echo -e "\n${GREEN}${BOLD}Monitoring:${NC}"
        echo -e "${YELLOW}  6)${NC} 📊 Show Caddy status"
        echo -e "${YELLOW}  7)${NC} 📜 View Caddy logs"
        
        echo -e "\n${GREEN}${BOLD}Certificate Management:${NC}"
        echo -e "${YELLOW}  8)${NC} 🔐 Manage SSL certificates"
        
        echo -e "\n${GREEN}${BOLD}Maintenance:${NC}"
        echo -e "${YELLOW}  9)${NC} 🔄 Update Caddy (with Cloudflare plugin)"
        
        echo -e "\n${RED}  0)${NC} ↩️  Exit\n"
        
        read -p "$(echo -e ${BOLD}Select option: ${NC})" choice
        
        case $choice in
            1) # Edit Caddyfile
                CADDYFILE="/etc/caddy/Caddyfile"
                if [ -f "$CADDYFILE" ]; then
                    echo -e "\n${CYAN}Opening Caddyfile...${NC}"
                    sudo ${EDITOR:-nano} "$CADDYFILE"
                else
                    echo -e "${RED}Caddyfile not found at $CADDYFILE${NC}"
                    read -p "Enter Caddyfile path: " custom_path
                    [ -f "$custom_path" ] && sudo ${EDITOR:-nano} "$custom_path"
                fi
                ;;
                
            2) # Show config
                echo -e "\n${CYAN}Current Caddyfile:${NC}\n"
                sudo cat /etc/caddy/Caddyfile | grep -v "^#" | grep -v "^$" | head -50
                echo -e "\n${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
                
            3) # Restart
                echo -e "\n${CYAN}Restarting Caddy...${NC}"
                if sudo systemctl restart caddy; then
                    echo -e "${GREEN}✓ Caddy restarted successfully!${NC}"
                else
                    echo -e "${RED}✗ Failed to restart Caddy${NC}"
                    echo -e "${YELLOW}Check configuration with: sudo caddy validate --config /etc/caddy/Caddyfile${NC}"
                fi
                sleep 2
                ;;
                
            4) # Stop
                echo -e "\n${YELLOW}⚠️  Stop Caddy?${NC}"
                read -p "Continue? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    sudo systemctl stop caddy
                    echo -e "${GREEN}✓ Caddy stopped${NC}"
                fi
                sleep 2
                ;;
                
            5) # Start
                echo -e "\n${CYAN}Starting Caddy...${NC}"
                if sudo systemctl start caddy; then
                    echo -e "${GREEN}✓ Caddy started successfully!${NC}"
                else
                    echo -e "${RED}✗ Failed to start Caddy${NC}"
                fi
                sleep 2
                ;;
                
            6) # Status
                echo -e "\n${CYAN}Caddy Service Status:${NC}\n"
                sudo systemctl status caddy --no-pager
                echo -e "\n${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
                
            7) # Logs
                echo -e "\n${CYAN}Caddy Logs (last 50 lines):${NC}\n"
                sudo journalctl -u caddy --no-pager -n 50
                echo -e "\n${YELLOW}Press q to quit, or follow with -f${NC}"
                read -p "Follow logs? (y/N): " -n 1 -r
                echo
                [[ $REPLY =~ ^[Yy]$ ]] && sudo journalctl -u caddy -f
                ;;
                
            8) # Certificate Management
                manage_certificates
                ;;
                
            9) # Update Caddy with Cloudflare plugin
                update_caddy_cloudflare
                ;;
                
            0) exit 0 ;;
            
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

# Start
caddy_menu

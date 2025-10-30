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
    
    # Check with sudo permission
    if ! sudo test -d "$CERT_DIR"; then
        echo -e "${YELLOW}Certificate directory not accessible at: $CERT_DIR${NC}"
        echo -e "${DIM}Checking with elevated permissions...${NC}"
        
        # Try to create/access the parent directories if they exist
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
        echo -e "${YELLOW}  4)${NC} 🗑️  Delete certificates for abandoned domain"
        echo -e "${YELLOW}  5)${NC} 📊 Show certificate disk usage"
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
                # Using sudo to read directories
                for acme_dir in $(sudo find "$CERT_DIR" -maxdepth 1 -type d); do
                    if [ "$acme_dir" != "$CERT_DIR" ]; then
                        echo -e "${GREEN}ACME Provider: $(basename "$acme_dir")${NC}"
                        for domain_dir in $(sudo find "$acme_dir" -maxdepth 1 -type d); do
                            if [ "$domain_dir" != "$acme_dir" ]; then
                                domain_name=$(basename "$domain_dir")
                                echo -e "  ${YELLOW}→${NC} $domain_name"
                                # Check for certificate files
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
                
                if [ -z "$domain_inspect" ]; then
                    echo -e "${RED}No domain entered${NC}"
                    sleep 2
                    continue
                fi
                
                found=false
                # Search in all ACME directories
                for acme_dir in $(sudo find "$CERT_DIR" -maxdepth 1 -type d); do
                    if [ "$acme_dir" != "$CERT_DIR" ]; then
                        domain_path="$acme_dir/$domain_inspect"
                        if sudo test -d "$domain_path"; then
                            found=true
                            echo -e "\n${GREEN}Certificate files for $domain_inspect:${NC}\n"
                            sudo ls -lah "$domain_path"
                            
                            # Show certificate info if exists
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
                
            4) # Delete abandoned domain certificates
                echo -e "\n${CYAN}Available domains with certificates:${NC}\n"
                domains=()
                
                # List all domains with sudo
                for acme_dir in $(sudo find "$CERT_DIR" -maxdepth 1 -type d); do
                    if [ "$acme_dir" != "$CERT_DIR" ]; then
                        for domain_dir in $(sudo find "$acme_dir" -maxdepth 1 -type d); do
                            if [ "$domain_dir" != "$acme_dir" ]; then
                                domain_name=$(basename "$domain_dir")
                                domains+=("$domain_name")
                                echo -e "  ${YELLOW}→${NC} $domain_name"
                            fi
                        done
                    fi
                done
                
                echo -e "\n${RED}⚠️  WARNING: This will permanently delete certificate files!${NC}"
                echo -e "${CYAN}Enter domain name to delete (or 'cancel' to abort):${NC}"
                read -p "Domain to delete: " domain_delete
                
                if [ "$domain_delete" = "cancel" ] || [ -z "$domain_delete" ]; then
                    echo -e "${YELLOW}Deletion cancelled${NC}"
                    sleep 2
                    continue
                fi
                
                found=false
                for acme_dir in $(sudo find "$CERT_DIR" -maxdepth 1 -type d); do
                    if [ "$acme_dir" != "$CERT_DIR" ]; then
                        domain_path="$acme_dir/$domain_delete"
                        if sudo test -d "$domain_path"; then
                            found=true
                            echo -e "\n${YELLOW}Found certificate directory:${NC}"
                            echo -e "$domain_path"
                            echo -e "\n${CYAN}Contents to be deleted:${NC}"
                            sudo ls -la "$domain_path"
                            
                            echo -e "\n${RED}Are you ABSOLUTELY SURE you want to delete all certificates for $domain_delete?${NC}"
                            read -p "Type 'DELETE' to confirm: " confirm_delete
                            
                            if [ "$confirm_delete" = "DELETE" ]; then
                                echo -e "${CYAN}Deleting certificate directory...${NC}"
                                if sudo rm -rf "$domain_path"; then
                                    echo -e "${GREEN}✓ Successfully deleted certificates for $domain_delete${NC}"
                                    
                                    # Also clean up any OCSP stapling files if they exist
                                    sudo rm -f "$acme_dir"/*"$domain_delete"*.ocsp 2>/dev/null
                                else
                                    echo -e "${RED}✗ Failed to delete certificate directory${NC}"
                                fi
                            else
                                echo -e "${YELLOW}Deletion cancelled${NC}"
                            fi
                            break
                        fi
                    fi
                done
                
                if [ "$found" = false ]; then
                    echo -e "${YELLOW}No certificates found for domain: $domain_delete${NC}"
                fi
                
                sleep 3
                ;;
                
            5) # Show disk usage
                echo -e "\n${CYAN}Certificate Storage Usage:${NC}\n"
                echo -e "${BOLD}Total usage:${NC}"
                sudo du -sh "$CERT_DIR" 2>/dev/null
                
                echo -e "\n${BOLD}Per ACME provider:${NC}"
                for acme_dir in $(sudo find "$CERT_DIR" -maxdepth 1 -type d); do
                    if [ "$acme_dir" != "$CERT_DIR" ]; then
                        size=$(sudo du -sh "$acme_dir" 2>/dev/null | cut -f1)
                        echo -e "${GREEN}$(basename "$acme_dir"):${NC} $size"
                    fi
                done
                
                echo -e "\n${BOLD}Per domain:${NC}"
                for acme_dir in $(sudo find "$CERT_DIR" -maxdepth 1 -type d); do
                    if [ "$acme_dir" != "$CERT_DIR" ]; then
                        for domain_dir in $(sudo find "$acme_dir" -maxdepth 1 -type d); do
                            if [ "$domain_dir" != "$acme_dir" ]; then
                                size=$(sudo du -sh "$domain_dir" 2>/dev/null | cut -f1)
                                echo -e "  ${YELLOW}$(basename "$domain_dir"):${NC} $size"
                            fi
                        done
                    fi
                done
                
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

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

caddy_menu() {
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
        echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        
        echo -e "${GREEN}${BOLD}Configuration:${NC}"
        echo -e "${YELLOW}  1)${NC} 📝 Edit Caddyfile"
        echo -e "${YELLOW}  2)${NC} ✅ Validate Caddyfile"
        echo -e "${YELLOW}  3)${NC} 📋 Show current config"
        
        echo -e "\n${GREEN}${BOLD}Service Control:${NC}"
        echo -e "${YELLOW}  4)${NC} 🔄 Reload Caddy"
        echo -e "${YELLOW}  5)${NC} 🔁 Restart Caddy"
        echo -e "${YELLOW}  6)${NC} ⏹️  Stop Caddy"
        echo -e "${YELLOW}  7)${NC} ▶️  Start Caddy"
        
        echo -e "\n${GREEN}${BOLD}Monitoring:${NC}"
        echo -e "${YELLOW}  8)${NC} 📊 Show Caddy status"
        echo -e "${YELLOW}  9)${NC} 📜 View Caddy logs"
        echo -e "${YELLOW} 10)${NC} 🔍 Test specific domain"
        
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
                
            2) # Validate
                echo -e "\n${CYAN}Validating Caddyfile...${NC}\n"
                if sudo caddy validate --config /etc/caddy/Caddyfile 2>&1; then
                    echo -e "\n${GREEN}✓ Configuration is valid!${NC}"
                else
                    echo -e "\n${RED}✗ Configuration has errors!${NC}"
                fi
                echo -e "\n${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
                
            3) # Show config
                echo -e "\n${CYAN}Current Caddyfile:${NC}\n"
                sudo cat /etc/caddy/Caddyfile | grep -v "^#" | grep -v "^$" | head -50
                echo -e "\n${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
                
            4) # Reload
                echo -e "\n${CYAN}Reloading Caddy...${NC}"
                if sudo systemctl reload caddy; then
                    echo -e "${GREEN}✓ Caddy reloaded successfully!${NC}"
                else
                    echo -e "${RED}✗ Failed to reload Caddy${NC}"
                fi
                sleep 2
                ;;
                
            5) # Restart
                echo -e "\n${CYAN}Restarting Caddy...${NC}"
                if sudo systemctl restart caddy; then
                    echo -e "${GREEN}✓ Caddy restarted successfully!${NC}"
                else
                    echo -e "${RED}✗ Failed to restart Caddy${NC}"
                fi
                sleep 2
                ;;
                
            6) # Stop
                echo -e "\n${YELLOW}⚠️  Stop Caddy?${NC}"
                read -p "Continue? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    sudo systemctl stop caddy
                    echo -e "${GREEN}✓ Caddy stopped${NC}"
                fi
                sleep 2
                ;;
                
            7) # Start
                echo -e "\n${CYAN}Starting Caddy...${NC}"
                if sudo systemctl start caddy; then
                    echo -e "${GREEN}✓ Caddy started successfully!${NC}"
                else
                    echo -e "${RED}✗ Failed to start Caddy${NC}"
                fi
                sleep 2
                ;;
                
            8) # Status
                echo -e "\n${CYAN}Caddy Service Status:${NC}\n"
                sudo systemctl status caddy --no-pager
                echo -e "\n${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
                
            9) # Logs
                echo -e "\n${CYAN}Caddy Logs (last 50 lines):${NC}\n"
                sudo journalctl -u caddy --no-pager -n 50
                echo -e "\n${YELLOW}Press q to quit, or follow with -f${NC}"
                read -p "Follow logs? (y/N): " -n 1 -r
                echo
                [[ $REPLY =~ ^[Yy]$ ]] && sudo journalctl -u caddy -f
                ;;
                
            10) # Test domain
                read -p "Enter domain to test: " domain
                if [ -n "$domain" ]; then
                    echo -e "\n${CYAN}Testing $domain...${NC}\n"
                    echo -e "${YELLOW}HTTP Response:${NC}"
                    curl -IL "https://$domain" 2>&1 | head -20
                    
                    echo -e "\n${YELLOW}DNS Resolution:${NC}"
                    dig +short "$domain"
                fi
                echo -e "\n${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
                
            0) exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

# Start
caddy_menu
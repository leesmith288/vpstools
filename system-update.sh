#!/bin/bash
# System Update & Cleanup - Part of VPS Tools Suite
# Host as: system-update.sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Main function
system_update() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}            🔄 System Update & Cleanup Tool               ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"
    
    # Detect OS
    if [ -f /etc/debian_version ]; then
        OS="debian"
        OS_NAME="Debian/Ubuntu"
    elif [ -f /etc/redhat-release ]; then
        OS="redhat"
        OS_NAME="RHEL/CentOS"
    elif [ -f /etc/arch-release ]; then
        OS="arch"
        OS_NAME="Arch Linux"
    else
        OS="unknown"
        OS_NAME="Unknown"
    fi
    
    echo -e "${BLUE}Detected OS: ${YELLOW}$OS_NAME${NC}"
    echo -e "${BLUE}Current Date: ${YELLOW}$(date)${NC}"
    echo -e "${BLUE}Uptime: ${YELLOW}$(uptime -p)${NC}"
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    # Show disk usage before
    echo -e "${CYAN}💾 Current Disk Usage:${NC}"
    df -h / | grep -E 'Filesystem|^/dev/'
    BEFORE_USED=$(df / | tail -1 | awk '{print $3}')
    echo ""
    
    read -p "$(echo -e ${YELLOW}Proceed with system update and cleanup? [y/N]: ${NC})" -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Operation cancelled${NC}"
        return
    fi
    
    echo ""
    
    case $OS in
        debian)
            echo -e "${GREEN}📋 Updating package lists...${NC}"
            sudo apt update
            
            # Show upgradable packages
            UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
            if [ "$UPGRADABLE" -gt 1 ]; then
                echo -e "\n${YELLOW}Found $((UPGRADABLE-1)) upgradable packages${NC}"
            fi
            
            echo -e "\n${GREEN}⬆️  Upgrading packages...${NC}"
            sudo apt upgrade -y
            
            echo -e "\n${GREEN}🧹 Removing unnecessary packages...${NC}"
            sudo apt autoremove -y
            
            echo -e "\n${GREEN}🗑️  Cleaning package cache...${NC}"
            sudo apt autoclean
            sudo apt clean
            
            # Check for old kernels
            echo -e "\n${GREEN}🔧 Checking for old kernels...${NC}"
            KERNEL_COUNT=$(dpkg -l 'linux-image-*' | grep ^ii | wc -l)
            echo -e "Installed kernels: $KERNEL_COUNT"
            ;;
            
        redhat)
            echo -e "${GREEN}📋 Updating packages...${NC}"
            if command -v dnf &> /dev/null; then
                sudo dnf update -y
                echo -e "\n${GREEN}🧹 Removing unnecessary packages...${NC}"
                sudo dnf autoremove -y
                echo -e "\n${GREEN}🗑️  Cleaning cache...${NC}"
                sudo dnf clean all
            else
                sudo yum update -y
                sudo yum autoremove -y
                sudo yum clean all
            fi
            ;;
            
        arch)
            echo -e "${GREEN}📋 Updating system...${NC}"
            sudo pacman -Syu --noconfirm
            
            echo -e "\n${GREEN}🧹 Removing orphaned packages...${NC}"
            orphans=$(pacman -Qtdq)
            if [ -n "$orphans" ]; then
                echo "$orphans" | sudo pacman -Rns - --noconfirm
            fi
            ;;
    esac
    
    # Common cleanup tasks
    echo -e "\n${GREEN}🧹 Performing common cleanup tasks...${NC}"
    
    # Clean temporary files
    echo -e "\n${BLUE}📁 Cleaning temporary files...${NC}"
    sudo find /tmp -type f -atime +7 -delete 2>/dev/null
    sudo find /var/tmp -type f -atime +7 -delete 2>/dev/null
    echo "  ✓ Cleaned old temporary files"
    
    # Clean journal logs
    if command -v journalctl &> /dev/null; then
        echo -e "\n${BLUE}📰 Cleaning system logs...${NC}"
        JOURNAL_SIZE=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+\.?\d*[MG]' || echo "0M")
        echo "  Current journal size: $JOURNAL_SIZE"
        sudo journalctl --vacuum-time=7d
        echo "  ✓ Cleaned logs older than 7 days"
    fi
    
    # Clean user cache (optional)
    if [ -d ~/.cache ]; then
        CACHE_SIZE=$(du -sh ~/.cache 2>/dev/null | cut -f1)
        echo -e "\n${BLUE}📦 User cache size: $CACHE_SIZE${NC}"
        read -p "Clean old cache files? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            find ~/.cache -type f -atime +30 -delete 2>/dev/null
            echo "  ✓ Cleaned cache files older than 30 days"
        fi
    fi
    
    # Show final disk usage
    echo -e "\n${CYAN}💾 Final Disk Usage:${NC}"
    df -h / | grep -E 'Filesystem|^/dev/'
    AFTER_USED=$(df / | tail -1 | awk '{print $3}')
    
    # Calculate space freed
    if command -v bc &> /dev/null; then
        FREED=$((BEFORE_USED - AFTER_USED))
        if [ $FREED -gt 0 ]; then
            FREED_MB=$((FREED / 1024))
            echo -e "\n${GREEN}✨ Freed approximately ${FREED_MB}MB of space${NC}"
        fi
    fi
    
    echo -e "\n${GREEN}✅ System update and cleanup completed!${NC}"
    
    # Check if reboot required
    if [ -f /var/run/reboot-required ]; then
        echo -e "\n${YELLOW}⚠️  System reboot required${NC}"
        read -p "Reboot now? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Rebooting in 5 seconds...${NC}"
            sleep 5
            sudo reboot
        fi
    fi
    
    echo -e "\n${YELLOW}Press Enter to exit...${NC}"
    read
}

# Start
system_update
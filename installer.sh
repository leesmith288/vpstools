#!/bin/bash
# VPS Tools Installer
# This script downloads and installs all VPS management tools

set -e  # Exit on any error

# Configuration
GITHUB_REPO="leesmith288/vpstools"
INSTALL_DIR="/opt/vpstools"
SCRIPTS=(
    "main.sh"
    "system-tools.sh"
    "system-update.sh"
    "security-check.sh"
    "docker-manager.sh"
    "caddy-manager.sh"
    "network-tools.sh"
)

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "🚀 Installing VPS Management Suite..."
echo ""

# Create installation directory
echo "📁 Creating directory: $INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"

# Download all scripts
for script in "${SCRIPTS[@]}"; do
    echo "📥 Downloading $script..."
    if sudo curl -sfL "https://raw.githubusercontent.com/$GITHUB_REPO/main/$script" -o "$INSTALL_DIR/$script"; then
        sudo chmod +x "$INSTALL_DIR/$script"
        sudo dos2unix "$INSTALL_DIR/$script" 2>/dev/null || sudo sed -i 's/\r$//' "$INSTALL_DIR/$script"
        echo -e "${GREEN}✓${NC} $script installed"
    else
        echo -e "${RED}✗${NC} Failed to download $script"
        exit 1
    fi
done

# Configure GitHub repository automatically
echo "⚙️  Configuring repository settings..."
echo "GITHUB_REPO=\"$GITHUB_REPO\"" | sudo tee "$INSTALL_DIR/config.sh" > /dev/null
echo "$GITHUB_REPO" | sudo tee "$INSTALL_DIR/.github-repo" > /dev/null

# Set correct permissions
sudo chmod 644 "$INSTALL_DIR/config.sh"
sudo chmod 644 "$INSTALL_DIR/.github-repo"

echo -e "${GREEN}✓${NC} Repository configured"


# Create a convenient symlink
sudo ln -sf "$INSTALL_DIR/main.sh" /usr/local/bin/vps-manager

echo ""
echo -e "${GREEN}✅ Installation complete!${NC}"
echo ""
echo "To start the VPS Management Suite, run:"
echo "  sudo vps-manager"
echo ""
echo "Or go to the installation directory:"
echo "  cd $INSTALL_DIR && sudo ./main.sh"

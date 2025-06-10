#!/bin/bash
# VPS Tools Installer (v2 - Dynamic)
# This script dynamically discovers and installs all .sh files from the repo.

set -e  # Exit on any error

# --- Configuration ---
GITHUB_REPO="leesmith288/vpstools"
INSTALL_DIR="/opt/vpstools"
# Files to exclude from installation (e.g., the installer itself if it's in the repo)
EXCLUDE_FILES=("installer.sh") 

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🚀 Installing VPS Management Suite...${NC}"
echo ""

# --- Dependency Check (jq) ---
if ! command -v jq &> /dev/null; then
    echo "jq (a command-line JSON processor) is not found. Attempting to install..."
    # Attempt to install jq for common distributions
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y jq
    elif command -v yum &> /dev/null; then
        sudo yum install -y jq
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y jq
    else
        echo -e "${RED}Could not auto-install jq. Please install it manually and re-run the script.${NC}"
        exit 1
    fi
fi

# --- Main Installation ---
# Create installation directory
echo "📁 Creating directory: $INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"

# Dynamically get the list of .sh files from GitHub
echo "🔎 Discovering scripts in repository: $GITHUB_REPO"
API_URL="https://api.github.com/repos/$GITHUB_REPO/contents/"
# Use jq to parse the JSON response and get the names of .sh files
SCRIPTS=($(curl -sL "$API_URL" | jq -r '.[] | select(.name | endswith(".sh")) | .name'))

if [ ${#SCRIPTS[@]} -eq 0 ]; then
    echo -e "${RED}✗ No .sh files found in the repository or failed to fetch from GitHub.${NC}"
    exit 1
fi

echo "Found scripts: ${SCRIPTS[*]}"
echo ""

# Download all discovered scripts
for script in "${SCRIPTS[@]}"; do
    # Check if the script is in the exclusion list
    should_exclude=false
    for excluded in "${EXCLUDE_FILES[@]}"; do
        if [[ "$script" == "$excluded" ]]; then
            should_exclude=true
            break
        fi
    done

    if [ "$should_exclude" = true ]; then
        echo -e "${YELLOW}⏭️  Skipping excluded file: $script${NC}"
        continue
    fi

    echo "📥 Downloading $script..."
    if sudo curl -sfL "https://raw.githubusercontent.com/$GITHUB_REPO/main/$script" -o "$INSTALL_DIR/$script"; then
        sudo chmod +x "$INSTALL_DIR/$script"
        # Handle Windows line endings just in case
        sudo sed -i 's/\r$//' "$INSTALL_DIR/$script"
        echo -e "${GREEN}✓${NC} $script installed"
    else
        echo -e "${RED}✗${NC} Failed to download $script"
        # Don't exit on a single failure, just warn
    fi
done

# --- Post-Installation ---
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

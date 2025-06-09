#!/bin/bash
# Uninstall VPS Tools

echo "🗑️ Uninstalling VPS Management Suite..."

# Remove the symlink
sudo rm -f /usr/local/bin/vps-manager

# Remove the installation directory
sudo rm -rf /opt/vpstools

# Remove config files
rm -f ~/.vps-quick-actions
rm -f ~/.vps-function-index

echo "✅ VPS Management Suite has been uninstalled"
echo ""
echo "To reinstall, run:"
echo "bash <(curl -fsSL https://raw.githubusercontent.com/leesmith288/vpstools/main/installer.sh)"

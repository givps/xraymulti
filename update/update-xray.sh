#!/bin/bash
# ==========================================
# Update Xray Core to Latest Official Release (Auto Arch Detection)
# ==========================================

set -euo pipefail

# Colors for output
green='\e[0;32m'
red='\e[1;31m'
yell='\e[1;33m'
NC='\e[0m'

# ===============================
# Ensure dependencies
# ===============================
echo -e "${green}INFO${NC}: Checking required packages..."
for pkg in curl wget unzip; do
    if ! command -v $pkg >/dev/null 2>&1; then
        echo -e "${yell}WARN${NC}: $pkg not found, installing..."
        apt update && apt install -y $pkg
    fi
done

# ===============================
# Stop Xray service
# ===============================
echo -e "${green}INFO${NC}: Stopping Xray service..."
systemctl stop xray || echo -e "${yell}WARN${NC}: Xray service not running."

# ===============================
# Detect VPS architecture
# ===============================
arch=$(uname -m)
case "$arch" in
    x86_64) arch="linux-64" ;;
    aarch64 | armv8*) arch="linux-arm64" ;;
    armv7* | armv6*) arch="linux-arm32-v7a" ;;
    *) 
        echo -e "${red}ERROR${NC}: Unsupported architecture: $arch"
        exit 1
        ;;
esac
echo -e "${green}INFO${NC}: Detected architecture: $arch"

# ===============================
# Detect latest release
# ===============================
echo -e "${green}INFO${NC}: Fetching latest Xray release..."
latest_url=$(curl -s https://api.github.com/repos/XTLS/Xray-core/releases/latest \
    | grep "browser_download_url.*${arch}.zip" \
    | cut -d '"' -f 4)

if [[ -z "$latest_url" ]]; then
    echo -e "${red}ERROR${NC}: Could not fetch latest release URL for $arch."
    exit 1
fi

# ===============================
# Download latest Xray
# ===============================
echo -e "${green}INFO${NC}: Downloading Xray core from $latest_url..."
wget -O /tmp/xray.zip "$latest_url"

# ===============================
# Extract and install
# ===============================
echo -e "${green}INFO${NC}: Extracting Xray core..."
unzip -o /tmp/xray.zip -d /tmp/xray_temp

echo -e "${green}INFO${NC}: Installing Xray binary..."
install -m 755 /tmp/xray_temp/xray /usr/local/bin/xray
install -m 755 /tmp/xray_temp/xray /usr/bin/xray  # optional backup

# ===============================
# Clean up
# ===============================
echo -e "${green}INFO${NC}: Cleaning up temporary files..."
rm -rf /tmp/xray.zip /tmp/xray_temp

# ===============================
# Restart service
# ===============================
echo -e "${green}INFO${NC}: Restarting Xray service..."
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# ===============================
# Display version and return to menu
# ===============================
echo -e "${green}INFO${NC}: Xray has been updated successfully to the latest version."
xray -version

read -n 1 -s -r -p "Press any key to return to the menu..."
echo
if [[ -x /usr/bin/menu ]]; then
    /usr/bin/menu
else
    echo "Menu script not found!"
fi

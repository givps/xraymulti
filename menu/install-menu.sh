#!/bin/bash
# ==========================================
# Install & Update XRAY Menu Scripts
# ==========================================
set -euo pipefail

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# --- Variables ---
XRAY_DIR="/usr/bin"
SCRIPTS=(
    "menu"
    "create"
    "delete"
    "crtxray"
    "restart-xray"
    "change-domain"
    "auto-delete"
    "change-dns"
    "auto-reboot"
    "update-xray"
)
BASE_URL="https://raw.githubusercontent.com/givps/xraymulti/master/menu"
UPDATE_URL="https://raw.githubusercontent.com/givps/xraymulti/master/update"

# --- Detect sudo/root ---
SUDO=""
if ! [ $(id -u) -eq 0 ]; then
    if command -v sudo &>/dev/null; then
        SUDO="sudo"
    else
        echo -e "${red}[ERROR]${nc} This script requires root or sudo access."
        exit 1
    fi
fi

# --- Check Internet ---
if ! ping -c1 github.com &>/dev/null; then
    echo -e "${red}[ERROR]${nc} No internet connection!"
    exit 1
fi

# --- Ensure dependencies ---
echo -e "${green}[INFO]${nc} Checking dependencies..."
DEPENDENCIES=(wget curl)
for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${yellow}[INFO]${nc} Installing missing dependency: $cmd"
        $SUDO apt-get update -y
        $SUDO apt-get install -y "$cmd"
    fi
done

# --- Navigate to XRAY directory ---
echo -e "${green}[INFO]${nc} Navigating to $XRAY_DIR..."
cd "$XRAY_DIR" || { echo -e "${red}[ERROR]${nc} Cannot access $XRAY_DIR"; exit 1; }

# --- Remove old scripts ---
echo -e "${green}[INFO]${nc} Removing old XRAY scripts..."
for script in "${SCRIPTS[@]}"; do
    [ -f "$script" ] && rm -f "$script"
done

# --- Download latest scripts ---
echo -e "${green}[INFO]${nc} Downloading latest XRAY scripts..."
for script in "${SCRIPTS[@]}"; do
    url="$BASE_URL/$script.sh"
    [[ "$script" == "update-xray" ]] && url="$UPDATE_URL/update-xray.sh"
    if wget -q -O "$script" "$url"; then
        chmod +x "$script"
        echo -e "${green}[OK]${nc} $script downloaded"
    else
        echo -e "${yellow}[WARNING]${nc} Failed to download $script"
    fi
done

# --- Install Speedtest CLI ---
echo -e "${green}[INFO]${nc} Installing Speedtest CLI..."
if ! command -v speedtest &> /dev/null; then
    $SUDO apt-get install -y speedtest-cli || echo -e "${yellow}[WARNING]${nc} Install manually"
else
    echo -e "${green}[INFO]${nc} Speedtest already installed"
fi

echo -e "${green}[INFO]${nc} XRAY scripts installation completed successfully!"


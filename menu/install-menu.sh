#!/bin/bash
# ==========================================
# Install XRAY Menu Scripts
# ==========================================
set -euo pipefail
IFS=$'\n\t'

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

# --- Ensure dependencies ---
echo "[INFO] Checking dependencies..."
DEPENDENCIES=(wget curl sudo)
for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "[INFO] Installing missing dependency: $cmd"
        apt-get update -y
        apt-get install -y "$cmd"
    fi
done

# --- Navigate to XRAY directory ---
echo "[INFO] Navigating to $XRAY_DIR..."
cd "$XRAY_DIR" || { echo "[ERROR] Cannot access $XRAY_DIR"; exit 1; }

# --- Remove old scripts ---
echo "[INFO] Removing old XRAY scripts..."
for script in "${SCRIPTS[@]}"; do
    rm -f "$script"
done

# --- Download latest scripts ---
echo "[INFO] Downloading latest XRAY scripts..."
for script in "${SCRIPTS[@]}"; do
    if [[ "$script" == "update-xray" ]]; then
        wget -q -O "$script" "$UPDATE_URL/update-xray.sh"
    else
        wget -q -O "$script" "$BASE_URL/$script.sh"
    fi
done

# --- Make scripts executable ---
echo "[INFO] Setting executable permissions..."
for script in "${SCRIPTS[@]}"; do
    chmod +x "$script"
done

# --- Install Speedtest CLI (Ookla) ---
echo "[INFO] Installing Speedtest CLI..."
if ! command -v speedtest &> /dev/null; then
    curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
    apt-get update -y
    if ! apt-get install -y speedtest; then
        echo "[WARNING] Speedtest installation failed. You can install manually."
    else
        echo "[INFO] Speedtest installed successfully."
    fi
else
    echo "[INFO] Speedtest already installed."
fi

echo "[INFO] XRAY scripts installation completed successfully!"

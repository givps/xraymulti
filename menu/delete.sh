#!/bin/bash
# =========================================
# Delete Xray User (VLESS, VMESS, TROJAN)
# Without jq - compatible with #vless/#vmess/#trojan tags
# =========================================

XRAY_CONF="/etc/xray/config.json"
LOG="/var/log/xray-user-delete.log"

# --- Color setup ---
red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;36m'
nc='\033[0m'

# --- Show user list ---
clear
echo -e "${blue}=========================================${nc}"
echo -e "${green}      XRAY USER DELETION MENU ${nc}"
echo -e "${blue}=========================================${nc}"

grep -E "^### " $XRAY_CONF | cut -d ' ' -f 2-3 | nl
echo -e "${blue}=========================================${nc}"
read -rp "Select user number to delete: " NUM

USER=$(grep -E "^### " $XRAY_CONF | cut -d ' ' -f 2 | sed -n "${NUM}p")
EXP_DATE=$(grep -E "^### " $XRAY_CONF | cut -d ' ' -f 3 | sed -n "${NUM}p")

if [[ -z $USER ]]; then
    echo -e "${red}No user found or invalid selection.${nc}"
    exit 1
fi

# --- Delete user entries ---
sed -i "/^### $USER $EXP_DATE/,/^###/d" $XRAY_CONF
sed -i "/^### $USER $EXP_DATE/d" $XRAY_CONF

# --- Restart Xray ---
systemctl restart xray >/dev/null 2>&1

# --- Verify ---
if systemctl is-active --quiet xray; then
    STATUS="${green}RUNNING${nc}"
else
    STATUS="${red}FAILED${nc}"
fi

# --- Log output ---
{
echo -e "${red}=========================================${nc}"
echo -e "${blue}         XRAY USER DELETED ${nc}"
echo -e "${red}=========================================${nc}"
echo "User          : $USER"
echo "Expired Date  : $EXP_DATE"
echo "Xray Status   : $STATUS"
echo -e "${red}=========================================${nc}"
} | tee -a "$LOG"

echo -e "${green}User '$USER' has been removed successfully.${nc}"
# Opsi kembali ke menu setelah selesai
if type menu >/dev/null 2>&1; then
    read -n1 -s -r -p "Press any key to return to menu..."
    echo ""
    menu
fi

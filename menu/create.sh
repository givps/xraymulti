#!/bin/bash
# =========================================
# Auto Create Xray User (VLESS, VMESS, TROJAN)
# Without jq, JSON-safe append using sed
# =========================================

# --- CONFIG ---
XRAY_CONF="/etc/xray/config.json"
LOG="/var/log/xray-user-create.log"

# --- Color setup ---
red='\033[0;31m'
green='\033[0;32m'
blue='\033[0;36m'
nc='\033[0m'

# --- Input user data ---
read -rp "Username : " USER
UUID=$(cat /proc/sys/kernel/random/uuid)
read -rp "Expired (days): " EXP_DAYS
EXP_DATE=$(date -d "$EXP_DAYS days" +"%Y-%m-%d")

# --- Create user entries ---
VLESS_USER=$(cat <<EOF
### $USER $EXP_DATE
{"id": "$UUID", "email": "$USER"}
EOF
)

VMESS_USER=$(cat <<EOF
### $USER $EXP_DATE
{"id": "$UUID", "alterId": 0, "email": "$USER"}
EOF
)

TROJAN_USER=$(cat <<EOF
### $USER $EXP_DATE
{"password": "$UUID", "email": "$USER"}
EOF
)

# --- Insert to config.json ---
# Add VLESS user
sed -i "/#vless$/a $VLESS_USER," $XRAY_CONF
# Add VMESS user
sed -i "/#vmess$/a $VMESS_USER," $XRAY_CONF
# Add TROJAN user
sed -i "/#trojan$/a $TROJAN_USER," $XRAY_CONF

# --- Restart Xray ---
systemctl restart xray >/dev/null 2>&1

# --- Check ---
if systemctl is-active --quiet xray; then
    STATUS="${green}RUNNING${nc}"
else
    STATUS="${red}FAILED${nc}"
fi

# --- Generate connection info ---
DOMAIN=$(cat /etc/xray/domain 2>/dev/null || echo "yourdomain.com")
VLESS_TLS="vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&type=ws#${USER}"
VLESS_NTLS="vless://${UUID}@${DOMAIN}:80?encryption=none&type=ws#${USER}"
VMESS_TLS="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"${USER}\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"tls\"}" | base64 -w0)"
VMESS_NTLS="vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"${USER}\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmess\",\"tls\":\"none\"}" | base64 -w0)"
TROJAN_TLS="trojan://${UUID}@${DOMAIN}:443?security=tls&type=ws#${USER}"
TROJAN_NTLS="trojan://${UUID}@${DOMAIN}:80?type=ws#${USER}"

# --- Display result ---
{
echo -e "${red}=========================================${nc}"
echo -e "${blue}         XRAY USER CREATED SUCCESSFULLY ${nc}"
echo -e "${red}=========================================${nc}"
echo "User          : $USER"
echo "UUID/Password : $UUID"
echo "Expired Date  : $EXP_DATE"
echo "Xray Status   : $STATUS"
echo -e "${red}=========================================${nc}"
echo "VLESS TLS     : $VLESS_TLS"
echo -e "${red}-----------------------------------------${nc}"
echo "VLESS NonTLS  : $VLESS_NTLS"
echo -e "${red}-----------------------------------------${nc}"
echo "VMess TLS     : $VMESS_TLS"
echo -e "${red}-----------------------------------------${nc}"
echo "VMess NonTLS  : $VMESS_NTLS"
echo -e "${red}-----------------------------------------${nc}"
echo "Trojan TLS    : $TROJAN_TLS"
echo -e "${red}-----------------------------------------${nc}"
echo "Trojan NonTLS : $TROJAN_NTLS"
echo -e "${red}=========================================${nc}"
} | tee -a "$LOG"

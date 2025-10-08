#!/bin/bash
# ==========================================
# XRAY Multi-Protocol User Generator (No JSON Edit)
# ==========================================
set -euo pipefail

# ----------------------
# Colors
# ----------------------
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# ----------------------
# Paths
# ----------------------
USER_DB="/etc/xray/user.txt"
PUBLIC_HTML="/home/vps/public_html"
LOG="/etc/log-create-user.log"
mkdir -p "$PUBLIC_HTML"
touch "$USER_DB" "$LOG"

# ----------------------
# Domain & Ports
# ----------------------
MYIP=$(curl -s ipv4.icanhazip.com || echo "127.0.0.1")
DOMAIN=$(cat /etc/xray/domain 2>/dev/null || echo "$MYIP")
BUG="bug.com"
TLS_PORT=443
NTLS_PORT=80

# ----------------------
# User input
# ----------------------
while true; do
    read -rp "Enter Username: " USER
    [[ -z "$USER" || "$USER" =~ [^a-zA-Z0-9_] ]] && echo -e "${red}Invalid username${nc}" && continue
    grep -qw "$USER" "$USER_DB" && echo -e "${red}User already exists${nc}" && exit 1
    break
done

read -rp "Expire in (days): " DAYS
[[ ! "$DAYS" =~ ^[0-9]+$ ]] && echo -e "${red}Invalid number${nc}" && exit 1
EXP_DATE=$(date -d "$DAYS days" +"%Y-%m-%d")
UUID=$(cat /proc/sys/kernel/random/uuid)

# ----------------------
# Save to database
# ----------------------
echo "$USER|$UUID|$EXP_DATE" >> "$USER_DB"

# ----------------------
# Generate links
# ----------------------
VLESS_TLS="vless://$UUID@$DOMAIN:$TLS_PORT?path=/vless&security=tls&encryption=none&type=ws&sni=$BUG#$USER"
VLESS_NTLS="vless://$UUID@$DOMAIN:$NTLS_PORT?path=/vless&security=none&encryption=none&type=ws#$USER"

VMESS_TLS_JSON=$(echo "{\"v\":\"2\",\"ps\":\"$USER\",\"add\":\"$DOMAIN\",\"port\":$TLS_PORT,\"id\":\"$UUID\",\"aid\":0,\"net\":\"ws\",\"type\":\"none\",\"host\":\"$BUG\",\"path\":\"/vmess\",\"tls\":\"tls\"}")
VMESS_NTLS_JSON=$(echo "{\"v\":\"2\",\"ps\":\"$USER\",\"add\":\"$DOMAIN\",\"port\":$NTLS_PORT,\"id\":\"$UUID\",\"aid\":0,\"net\":\"ws\",\"type\":\"none\",\"host\":\"$BUG\",\"path\":\"/vmess\",\"tls\":\"none\"}")
VMESS_TLS="vmess://$(echo "$VMESS_TLS_JSON" | base64 -w0)"
VMESS_NTLS="vmess://$(echo "$VMESS_NTLS_JSON" | base64 -w0)"

TROJAN_TLS="trojan://$UUID@$DOMAIN:$TLS_PORT?path=/trojan&security=tls&type=ws&host=$BUG&sni=$BUG#$USER"
TROJAN_NTLS="trojan://$UUID@$DOMAIN:$NTLS_PORT?path=/trojan&security=none&type=ws#$USER"

# ----------------------
# Save user info to HTML
# ----------------------
USER_FILE="$PUBLIC_HTML/$USER.txt"
{
  echo "USER: $USER"
  echo "UUID: $UUID"
  echo "Expired: $EXP_DATE"
  echo ""
  echo "VLESS TLS: $VLESS_TLS"
  echo "VLESS NonTLS: $VLESS_NTLS"
  echo ""
  echo "VMESS TLS: $VMESS_TLS"
  echo "VMESS NonTLS: $VMESS_NTLS"
  echo ""
  echo "TROJAN TLS: $TROJAN_TLS"
  echo "TROJAN NonTLS: $TROJAN_NTLS"
} > "$USER_FILE"
chmod 644 "$USER_FILE"

# ----------------------
# Restart services
# ----------------------
systemctl unmask xray 2>/dev/null || true
systemctl enable xray 2>/dev/null || true
systemctl restart xray 2>/dev/null || echo -e "${red}[!] Failed to restart Xray${nc}"
systemctl restart nginx 2>/dev/null || echo -e "${red}[!] Failed to restart Nginx${nc}"

# ----------------------
# Log & output
# ----------------------
{
echo -e "${red}=========================================${nc}"
echo -e "${blue}           XRAY USER CREATED ${nc}"
echo -e "${red}=========================================${nc}"
echo "User: $USER"
echo "UUID/Password: $UUID"
echo "Expired: $EXP_DATE"
echo -e "${red}=========================================${nc}"
echo "VLESS WS (TLS): $VLESS_TLS"
echo -e "${red}=========================================${nc}"
echo "VLESS WS (NonTLS): $VLESS_NTLS"
echo -e "${red}=========================================${nc}"
echo "VMess WS (TLS): $VMESS_TLS"
echo -e "${red}=========================================${nc}"
echo "VMess WS (NonTLS): $VMESS_NTLS"
echo -e "${red}=========================================${nc}"
echo "Trojan WS (TLS): $TROJAN_TLS"
echo -e "${red}=========================================${nc}"
echo "Trojan WS (NonTLS): $TROJAN_NTLS"
echo -e "${red}=========================================${nc}"
} | tee -a "$LOG"

echo -e "\n${green}✅ Done.${nc} Configs saved in ${yellow}$PUBLIC_HTML/${USER}.txt${nc}"

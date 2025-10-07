#!/bin/bash
set -euo pipefail

# ============================
# XRAY Account Creator (jq-free)
# ============================

# Colors
red='\e[1;31m'; green='\e[0;32m'; yellow='\e[1;33m'; blue='\e[1;34m'; nc='\e[0m'

LOG="/etc/log-create-user.log"
PUBLIC_HTML="/home/vps/public_html"
CONFIG_FILE="/etc/xray/config.json"

mkdir -p "$PUBLIC_HTML"
touch "$LOG"

# External IP & domain
MYIP=$(wget -qO- ipv4.icanhazip.com 2>/dev/null || curl -s ifconfig.me 2>/dev/null || echo "127.0.0.1")
domain=$(cat /etc/xray/domain 2>/dev/null || echo "$MYIP")

# Prompt username
while true; do
    read -rp "Username: " user
    user="${user// /}"
    if [[ ! $user =~ ^[a-zA-Z0-9_]+$ ]]; then
        echo -e "${red}Invalid username.${nc} Only letters, numbers, underscore."
        continue
    fi
    # Check if user exists by scanning config.json
    if grep -q "\"email\":\"$user\"" "$CONFIG_FILE" 2>/dev/null; then
        echo -e "${red}User already exists. Choose another.${nc}"
        continue
    fi
    break
done

# Expiry & UUID
read -rp "Expired (days): " expired
if ! [[ "$expired" =~ ^[0-9]+$ ]]; then
    echo -e "${red}Invalid number of days.${nc}"
    exit 1
fi
exp=$(date -d "$expired days" +"%Y-%m-%d")
uuid=$(cat /proc/sys/kernel/random/uuid)

# Defaults
TLS_PORT=443
GRPC_PORT=443
SS_CIPHER="aes-128-gcm"
BUG="bug.com"

# ----------------------
# Add user to config.json (simple append)
# ----------------------
add_client() {
    local proto="$1"
    local block=""
    case "$proto" in
        vless)
            block="{\"id\":\"$uuid\",\"email\":\"$user\"}"
            ;;
        vmess)
            block="{\"id\":\"$uuid\",\"email\":\"$user\",\"alterId\":0}"
            ;;
        trojan)
            block="{\"password\":\"$uuid\",\"email\":\"$user\"}"
            ;;
        ss)
            block="{\"password\":\"$uuid\",\"method\":\"$SS_CIPHER\",\"email\":\"$user\"}"
            ;;
    esac
    # Append block to clients array
    sed -i "/\"$proto\" *: *{/,/clients *:/s/\(\]/\1,\n$block/" "$CONFIG_FILE"
}

for proto in vless vmess trojan ss; do
    add_client "$proto"
done

# Restart XRAY
systemctl restart xray

# ----------------------
# Build links
# ----------------------
vless_ws="vless://${uuid}@${domain}:${TLS_PORT}?path=/vless&security=tls&encryption=none&type=ws#${user}"
vless_grpc="vless://${uuid}@${domain}:${GRPC_PORT}?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=${BUG}#${user}"

# VMess base64 (manual JSON)
vmess_ws_json='{"v":"2","ps":"'"$user"'","add":"'"$domain"'","port":'"$TLS_PORT',"id":"'"$uuid"'","aid":"0","net":"ws","type":"none","host":"","path":"/vmess"}'
vmess_ws=$(echo -n "$vmess_ws_json" | base64 -w0)
vmess_grpc_json='{"v":"2","ps":"'"$user"'","add":"'"$domain"'","port":'"$GRPC_PORT',"id":"'"$uuid"'","aid":"0","net":"grpc","type":"none","host":"","path":"","serviceName":"vmess-grpc"}'
vmess_grpc=$(echo -n "$vmess_grpc_json" | base64 -w0)

trojan_ws="trojan://${uuid}@${domain}:${TLS_PORT}?path=/trojan&security=tls&host=${BUG}&type=ws&sni=${BUG}#${user}"
trojan_grpc="trojan://${uuid}@${domain}:${GRPC_PORT}?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=${BUG}#${user}"

ss_b64=$(echo -n "$SS_CIPHER:$uuid" | base64 -w0)
ss_ws="ss://${ss_b64}@${domain}:${TLS_PORT}?plugin=xray-plugin;mux=0;path=/ssws;host=${domain};tls#${user}"
ss_grpc="ss://${ss_b64}@${domain}:${TLS_PORT}?plugin=xray-plugin;mux=0;serviceName=ss-grpc;host=${domain};tls#${user}"

# ----------------------
# Save TXT/JSON
# ----------------------
cat > "${PUBLIC_HTML}/ss-ws-${user}.json" <<EOF
{
  "server":"$domain",
  "server_port":$TLS_PORT,
  "password":"$uuid",
  "method":"$SS_CIPHER",
  "plugin":"xray-plugin",
  "plugin_opts":"path=/ssws;host=$domain;tls",
  "name":"$user"
}
EOF

cat > "${PUBLIC_HTML}/ss-grpc-${user}.json" <<EOF
{
  "server":"$domain",
  "server_port":$TLS_PORT,
  "password":"$uuid",
  "method":"$SS_CIPHER",
  "plugin":"xray-plugin",
  "plugin_opts":"serviceName=ss-grpc;host=$domain;tls",
  "name":"$user"
}
EOF

chmod 644 "${PUBLIC_HTML}/ss-"*.json

# TXT quick links
echo -e "$vless_ws\n$vless_grpc" > "${PUBLIC_HTML}/vless-${user}.txt"
echo -e "$vmess_ws\n$vmess_grpc" > "${PUBLIC_HTML}/vmess-${user}.txt"
echo -e "$trojan_ws\n$trojan_grpc" > "${PUBLIC_HTML}/trojan-${user}.txt"
echo -e "$ss_ws\n$ss_grpc" > "${PUBLIC_HTML}/ss-${user}.txt"

chmod 644 "${PUBLIC_HTML}"/*.txt

# ----------------------
# Log & output
# ----------------------
{
echo -e "${red}=========================================${nc}"
echo -e "${blue}            XRAY ACCOUNT  ${nc}"
echo -e "${red}=========================================${nc}"
echo "XRAY User Created: $user"
echo "UUID/Password: $uuid"
echo "Expired: $exp"
echo "VLESS WS: $vless_ws"
echo "VLESS gRPC: $vless_grpc"
echo "VMess WS: $vmess_ws"
echo "VMess gRPC: $vmess_grpc"
echo "Trojan WS: $trojan_ws"
echo "Trojan gRPC: $trojan_grpc"
echo "Shadowsocks WS: $ss_ws"
echo "Shadowsocks gRPC: $ss_grpc"
echo -e "${red}=========================================${nc}"
} | tee -a "$LOG"

read -n1 -s -r -p "Press any key to return to menu..."

menu



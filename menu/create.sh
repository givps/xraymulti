#!/bin/bash
set -euo pipefail

# -------------------------
# Colors
# -------------------------
red='\e[1;31m'; green='\e[0;32m'; yellow='\e[1;33m'; blue='\e[1;34m'; nc='\e[0m'

# -------------------------
# Paths & defaults
# -------------------------
PUBLIC_HTML="/home/vps/public_html"
mkdir -p "$PUBLIC_HTML"

BUG="bug.com"
TLS_PORT=443
GRPC_PORT=443
SS_CIPHER="aes-128-gcm"

# -------------------------
# External IP & domain
# -------------------------
domain=$(cat /etc/xray/domain 2>/dev/null || echo "127.0.0.1")

# -------------------------
# Prompt username
# -------------------------
while true; do
    read -rp "Username: " user
    user="${user// /}"
    if [[ ! $user =~ ^[a-zA-Z0-9_]+$ ]]; then
        echo -e "${red}Invalid username.${nc} Only letters, numbers, underscore."
        continue
    fi
    # Check if user already exists
    if [[ -f "$PUBLIC_HTML/vless-${user}.txt" ]]; then
        echo -e "${red}User already exists.${nc} Choose another."
        continue
    fi
    break
done

# -------------------------
# Expiry & UUID
# -------------------------
read -rp "Expired (days): " expired
if ! [[ "$expired" =~ ^[0-9]+$ ]]; then
    echo -e "${red}Invalid number of days.${nc}"
    exit 1
fi
exp=$(date -d "$expired days" +"%Y-%m-%d")
uuid=$(cat /proc/sys/kernel/random/uuid)

# -------------------------
# Build links
# -------------------------
vless_ws="vless://${uuid}@${domain}:${TLS_PORT}?path=/vless&security=tls&encryption=none&type=ws#${user}"
vless_grpc="vless://${uuid}@${domain}:${GRPC_PORT}?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=${BUG}#${user}"

vmess_ws=$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":$TLS_PORT,\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"\",\"path\":\"/vmess\"}" | base64 -w0)
vmess_grpc=$(echo -n "{\"v\":\"2\",\"ps\":\"$user\",\"add\":\"$domain\",\"port\":$GRPC_PORT,\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"grpc\",\"type\":\"none\",\"host\":\"\",\"path\":\"\",\"serviceName\":\"vmess-grpc\"}" | base64 -w0)

trojan_ws="trojan://${uuid}@${domain}:${TLS_PORT}?path=/trojan&security=tls&host=${BUG}&type=ws&sni=${BUG}#${user}"
trojan_grpc="trojan://${uuid}@${domain}:${GRPC_PORT}?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=${BUG}#${user}"

ss_b64=$(echo -n "$SS_CIPHER:$uuid" | base64 -w0)
ss_ws="ss://${ss_b64}@${domain}:${TLS_PORT}?plugin=xray-plugin;mux=0;path=/ssws;host=${domain};tls#${user}"
ss_grpc="ss://${ss_b64}@${domain}:${TLS_PORT}?plugin=xray-plugin;mux=0;serviceName=ss-grpc;host=${domain};tls#${user}"

# -------------------------
# Generate JSON configs
# -------------------------
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

# -------------------------
# Save quick-links per protocol
# -------------------------
echo -e "$vless_ws\n$vless_grpc" > "${PUBLIC_HTML}/vless-${user}.txt"
echo -e "$vmess_ws\n$vmess_grpc" > "${PUBLIC_HTML}/vmess-${user}.txt"
echo -e "$trojan_ws\n$trojan_grpc" > "${PUBLIC_HTML}/trojan-${user}.txt"
echo -e "$ss_ws\n$ss_grpc" > "${PUBLIC_HTML}/ss-${user}.txt"

chmod 644 "${PUBLIC_HTML}"/*.json "${PUBLIC_HTML}"/*.txt

# -------------------------
# Show summary
# -------------------------
echo -e "${red}=========================================${nc}"
echo -e "${blue}            XRAY ACCOUNT  ${nc}"
echo -e "${red}=========================================${nc}"
echo "XRAY User Created: $user"
echo "UUID/Password: $uuid"
echo "Expired: $exp"
echo -e "${red}=========================================${nc}"
echo "VLESS WS: $vless_ws"
echo -e "${red}=========================================${nc}"
echo "VLESS gRPC: $vless_grpc"
echo -e "${red}=========================================${nc}"
echo "VMess WS: $vmess_ws"
echo -e "${red}=========================================${nc}"
echo "VMess gRPC: $vmess_grpc"
echo -e "${red}=========================================${nc}"
echo "Trojan WS: $trojan_ws"
echo -e "${red}=========================================${nc}"
echo "Trojan gRPC: $trojan_grpc"
echo -e "${red}=========================================${nc}"
echo "Shadowsocks WS: $ss_ws"
echo -e "${red}=========================================${nc}"
echo "Shadowsocks gRPC: $ss_grpc"
echo -e "${red}=========================================${nc}"

read -n1 -s -r -p "Press any key to return to menu..."

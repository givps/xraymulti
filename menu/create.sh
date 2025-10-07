#!/bin/bash
# ==========================================
# Create XRAY Multi-Protocol Account (jq-safe, structured)
# ==========================================
set -euo pipefail

# Colors
red='\e[1;31m'; green='\e[0;32m'; yellow='\e[1;33m'; blue='\e[1;34m'; nc='\e[0m'

LOG="/etc/log-create-user.log"
PUBLIC_HTML="/home/vps/public_html"
CONFIG_FILE="/etc/xray/config.json"

# Defaults
BUG="bug.com"
TLS_PORT=443
GRPC_PORT=443
TCP_PORT=2083
SS_CIPHER="aes-128-gcm"

mkdir -p "$PUBLIC_HTML"
touch "$LOG"

# Ensure jq installed
if ! command -v jq &> /dev/null; then
    echo -e "${yellow}[!] jq not found, installing...${nc}"
    apt install -y jq >/dev/null 2>&1 || yum install -y jq >/dev/null 2>&1
fi

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
    # Check all protocols for duplicate
    exists=false
    for proto in trojan trojangrpc vless vmess ssws ssgrpc; do
        if jq -e ".$proto.clients[]? | select(.email==\"$user\")" "$CONFIG_FILE" >/dev/null; then
            exists=true
            break
        fi
    done
    if $exists; then
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

# Function to safely add client to JSON
add_client() {
    local proto="$1"
    local entry=""
    case "$proto" in
        trojan|trojangrpc)
            entry=$(jq -n --arg uuid "$uuid" --arg email "$user" '{password:$uuid,email:$email}')
            jq ".$proto.clients += [$entry]" "$CONFIG_FILE" > tmp.json && mv tmp.json "$CONFIG_FILE"
            ;;
        vless|vmess)
            entry=$(jq -n --arg uuid "$uuid" --arg email "$user" '{id:$uuid,email:$email}')
            jq ".$proto.clients += [$entry]" "$CONFIG_FILE" > tmp.json && mv tmp.json "$CONFIG_FILE"
            ;;
        ssws|ssgrpc)
            entry=$(jq -n --arg uuid "$uuid" --arg method "$SS_CIPHER" --arg email "$user" '{password:$uuid,method:$method,email:$email}')
            jq ".shadowsocks.clients += [$entry]" "$CONFIG_FILE" > tmp.json && mv tmp.json "$CONFIG_FILE"
            ;;
    esac
}

# Add user to all protocols
for proto in trojan trojangrpc vless vmess ssws ssgrpc; do
    add_client "$proto"
done

# Restart XRAY
if ! systemctl restart xray >/dev/null 2>&1; then
    echo -e "${yellow}[!] Warning: XRAY restart failed.${nc}"
fi

# ----------------------
# Build links
# ----------------------
vless_ws="vless://${uuid}@${domain}:${TLS_PORT}?path=/vless&security=tls&encryption=none&type=ws#${user}"
vless_grpc="vless://${uuid}@${domain}:${GRPC_PORT}?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=${BUG}#${user}"

vmess_ws=$(jq -n --arg id "$uuid" --arg add "$domain" --arg port "$TLS_PORT" --arg net "ws" --arg path "/vmess" --arg type "none" \
  '{v:"2",ps:$user,add:$add,port:$port|tonumber,id:$id,aid:"0",net:$net,type:$type,host:"",path:$path}' | base64 -w0)
vmess_grpc=$(jq -n --arg id "$uuid" --arg add "$domain" --arg port "$GRPC_PORT" --arg net "grpc" --arg type "none" --arg serviceName "vmess-grpc" \
  '{v:"2",ps:$user,add:$add,port:$port|tonumber,id:$id,aid:"0",net:$net,type:$type,host:"",path:"",serviceName:$serviceName}' | base64 -w0)

trojan_ws="trojan://${uuid}@${domain}:${TLS_PORT}?path=/trojan&security=tls&host=${BUG}&type=ws&sni=${BUG}#${user}"
trojan_grpc="trojan://${uuid}@${domain}:${GRPC_PORT}?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=${BUG}#${user}"

ss_b64=$(echo -n "$SS_CIPHER:$uuid" | base64 -w0)
ss_ws="ss://${ss_b64}@${domain}:${TLS_PORT}?plugin=xray-plugin;mux=0;path=/ssws;host=${domain};tls#${user}"
ss_grpc="ss://${ss_b64}@${domain}:${TLS_PORT}?plugin=xray-plugin;mux=0;serviceName=ss-grpc;host=${domain};tls#${user}"

# ----------------------
# Generate JSON configs
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

chmod 644 "${PUBLIC_HTML}/ss-ws-${user}.json" "${PUBLIC_HTML}/ss-grpc-${user}.json"

# ----------------------
# Save quick-links per protocol
# ----------------------
for proto in vless vmess trojan ss; do
  case "$proto" in
    vless) echo -e "$vless_ws\n$vless_grpc" > "${PUBLIC_HTML}/${proto}-${user}.txt" ;;
    vmess) echo -e "$vmess_ws\n$vmess_grpc" > "${PUBLIC_HTML}/${proto}-${user}.txt" ;;
    trojan) echo -e "$trojan_tcp_tls\n$trojan_tcp_plain\n$trojan_ws\n$trojan_grpc" > "${PUBLIC_HTML}/${proto}-${user}.txt" ;;
    ss) echo -e "$ss_ws\n$ss_grpc" > "${PUBLIC_HTML}/${proto}-${user}.txt" ;;
  esac
done
chmod 644 "${PUBLIC_HTML}"/*.txt

# ----------------------
# Log output
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

echo -e "\nDone. JSON & TXT configs saved in ${PUBLIC_HTML}"
read -n1 -s -r -p "Press any key to return to menu..."

menu

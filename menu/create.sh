#!/bin/bash
# ==========================================
# XRAY Multi-Protocol User + Auto Nginx Config
# ==========================================
set -euo pipefail

# ----------------------
# Colors
# ----------------------
red='\e[1;31m'; green='\e[0;32m'; yellow='\e[1;33m'; blue='\e[1;34m'; nc='\e[0m'

# ----------------------
# Paths
# ----------------------
CONFIG_FILE="/etc/xray/config.json"
PUBLIC_HTML="/home/vps/public_html"
LOG="/etc/log-create-user.log"
NGINX_CONF="/etc/nginx/conf.d/xray.conf"

mkdir -p "$PUBLIC_HTML"
touch "$LOG"

# ----------------------
# Domain
# ----------------------
MYIP=$(curl -s ifconfig.me || echo "127.0.0.1")
DOMAIN=$(cat /etc/xray/domain 2>/dev/null || echo "$MYIP")
BUG="bug.com"

# ----------------------
# Prompt user
# ----------------------
while true; do
    read -rp "Username: " USER
    USER="${USER// /}"
    [[ ! $USER =~ ^[a-zA-Z0-9_]+$ ]] && echo -e "${red}Invalid username${nc}" && continue
    break
done

read -rp "Expired (days): " EXPIRED
[[ ! "$EXPIRED" =~ ^[0-9]+$ ]] && echo -e "${red}Invalid number of days${nc}" && exit 1
EXP_DATE=$(date -d "$EXPIRED days" +"%Y-%m-%d")

# ----------------------
# UUID/Password
# ----------------------
UUID=$(cat /proc/sys/kernel/random/uuid)
SS_CIPHER="aes-128-gcm"

# ----------------------
# Function add client
# ----------------------
add_client() {
    PROTO="$1"
    case "$PROTO" in
        trojan|trojangrpc)
            echo "{\"password\":\"$UUID\",\"email\":\"$USER\"}" >> /tmp/${PROTO}_clients.tmp
            ;;
        vless|vmess)
            echo "{\"id\":\"$UUID\",\"email\":\"$USER\"}" >> /tmp/${PROTO}_clients.tmp
            ;;
        ssws|ssgrpc)
            echo "{\"password\":\"$UUID\",\"method\":\"$SS_CIPHER\",\"email\":\"$USER\"}" >> /tmp/${PROTO}_clients.tmp
            ;;
    esac
}

# ----------------------
# Add user to all protocols
# ----------------------
for proto in trojan trojangrpc vless vmess ssws ssgrpc; do
    add_client "$proto"
done

# ----------------------
# Generate Nginx config
# ----------------------
cat > "$NGINX_CONF" <<EOF
    server {
             listen 80;
             listen [::]:80;
             listen 8080;
             listen [::]:8080;
             listen 8880;
             listen [::]:8880;	
             server_name $domain *.$domain;
             ssl_certificate /etc/xray/xray.crt;
             ssl_certificate_key /etc/xray/xray.key;
             ssl_ciphers EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:EECDH+ECDSA+3DES:EECDH+aRSA+3DES:RSA+3DES:!MD5;
             ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
             root /usr/share/nginx/html;
        }
EOF

nginx -t && systemctl restart nginx
systemctl restart xray

# ----------------------
# Generate quick-links
# ----------------------
VLESS_WS="vless://$UUID@$DOMAIN:443?path=/vless&security=tls&encryption=none&type=ws#$USER"
VLESS_GRPC="vless://$UUID@$DOMAIN:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=$BUG#$USER"

VMESS_WS=$(echo "{\"v\":\"2\",\"ps\":\"$USER\",\"add\":\"$DOMAIN\",\"port\":443,\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"\",\"path\":\"/vmess\"}" | base64 -w0)
VMESS_GRPC=$(echo "{\"v\":\"2\",\"ps\":\"$USER\",\"add\":\"$DOMAIN\",\"port\":443,\"id\":\"$UUID\",\"aid\":\"0\",\"net\":\"grpc\",\"type\":\"none\",\"host\":\"\",\"path\":\"\",\"serviceName\":\"vmess-grpc\"}" | base64 -w0)

TROJAN_WS="trojan://$UUID@$DOMAIN:443?path=/trojan&security=tls&host=$BUG&type=ws&sni=$BUG#$USER"
TROJAN_GRPC="trojan://$UUID@$DOMAIN:443?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=$BUG#$USER"

SS_B64=$(echo -n "$SS_CIPHER:$UUID" | base64 -w0)
SS_WS="ss://$SS_B64@$DOMAIN:443?plugin=xray-plugin;mux=0;path=/ssws;host=$DOMAIN;tls#$USER"
SS_GRPC="ss://$SS_B64@$DOMAIN:443?plugin=xray-plugin;mux=0;serviceName=ss-grpc;host=$DOMAIN;tls#$USER"

# ----------------------
# Save to HTML folder
# ----------------------
for proto in vless vmess trojan ss; do
  case "$proto" in
    vless) echo -e "$VLESS_WS\n$VLESS_GRPC" > "$PUBLIC_HTML/${proto}-$USER.txt" ;;
    vmess) echo -e "$VMESS_WS\n$VMESS_GRPC" > "$PUBLIC_HTML/${proto}-$USER.txt" ;;
    trojan) echo -e "$TROJAN_WS\n$TROJAN_GRPC" > "$PUBLIC_HTML/${proto}-$USER.txt" ;;
    ss) echo -e "$SS_WS\n$SS_GRPC" > "$PUBLIC_HTML/${proto}-$USER.txt" ;;
  esac
done

chmod 644 "$PUBLIC_HTML"/*.txt

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
echo "VLESS WS: $VLESS_WS"
echo -e "${red}=========================================${nc}"
echo "VLESS gRPC: $VLESS_GRPC"
echo -e "${red}=========================================${nc}"
echo "VMess WS: $VMESS_WS"
echo -e "${red}=========================================${nc}"
echo "VMess gRPC: $VMESS_GRPC"
echo -e "${red}=========================================${nc}"
echo "Trojan WS: $TROJAN_WS"
echo -e "${red}=========================================${nc}"
echo "Trojan gRPC: $TROJAN_GRPC"
echo -e "${red}=========================================${nc}"
echo "Shadowsocks WS: $SS_WS"
echo -e "${red}=========================================${nc}"
echo "Shadowsocks gRPC: $SS_GRPC"
echo -e "${red}=========================================${nc}"
} | tee -a "$LOG"

echo -e "\nDone. Configs saved in $PUBLIC_HTML"

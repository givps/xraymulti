#!/bin/bash
set -euo pipefail

# ------------------------------------------
# Colors
# ------------------------------------------
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

#delete old
rm -f /etc/xray/xray.crt
rm -f /etc/xray/xray.key

# ------------------------------------------
# Log setup
# ------------------------------------------
LOG_FILE="/var/log/acme-install.log"
mkdir -p /var/log

# Auto log rotation (max 1MB, keep 3 backups)
if [[ -f "$LOG_FILE" ]]; then
    LOG_SIZE=$(stat -c%s "$LOG_FILE")
    if (( LOG_SIZE > 1048576 )); then
        timestamp=$(date +%Y%m%d-%H%M%S)
        mv "$LOG_FILE" "${LOG_FILE}.${timestamp}.bak"
        ls -tp /var/log/acme-install.log.*.bak 2>/dev/null | tail -n +4 | xargs -r rm --
        echo "[$(date)] Log rotated: $LOG_FILE" > "$LOG_FILE"
    fi
fi

# Redirect all output to log
exec > >(tee -a "$LOG_FILE") 2>&1

clear
echo -e "${green}Starting ACME.sh installation with Cloudflare DNS API...${nc}"

# ------------------------------------------
# Check domain
# ------------------------------------------
if [[ ! -f /etc/xray/domain ]]; then
    echo -e "${red}[ERROR]${nc} File /etc/xray/domain not found!"
    exit 1
fi

domain=$(cat /etc/xray/domain)
if [[ -z "$domain" ]]; then
    echo -e "${red}[ERROR]${nc} Domain is empty in /etc/xray/domain!"
    exit 1
fi

# ------------------------------------------
# Cloudflare Token (default + manual input)
# ------------------------------------------
DEFAULT_CF_TOKEN="GxfBrA3Ez39MdJo53EV-LiC4dM1-xn5rslR-m5Ru"
echo -e "${blue}Cloudflare API Token Setup:${nc}"
read -rp "Enter Cloudflare API Token (press ENTER to use default token): " CF_Token
if [[ -z "$CF_Token" ]]; then
    CF_Token="$DEFAULT_CF_TOKEN"
    echo -e "${green}[INFO]${nc} Using default Cloudflare API Token."
else
    echo -e "${green}[INFO]${nc} Using manually entered Cloudflare API Token."
fi
export CF_Token


# ------------------------------------------
# Install dependencies
# ------------------------------------------
echo -e "${blue}Installing dependencies...${nc}"
apt update -y >/dev/null 2>&1
command -v curl >/dev/null 2>&1 || apt install -y curl >/dev/null 2>&1
command -v jq >/dev/null 2>&1 || apt install -y jq >/dev/null 2>&1

# ------------------------------------------
# Retry helper
# ------------------------------------------
retry() {
    local MAX_RETRY=5 COUNT=0
    local CMD=("$@")
    until [ $COUNT -ge $MAX_RETRY ]; do
        if "${CMD[@]}"; then
            return 0
        fi
        COUNT=$((COUNT + 1))
        echo -e "${yellow}Command failed. Retry $COUNT/$MAX_RETRY...${nc}"
        sleep 3
    done
    echo -e "${red}Command failed after $MAX_RETRY retries.${nc}"
    exit 1
}

# ------------------------------------------
# Install acme.sh
# ------------------------------------------
ACME_HOME="$HOME/.acme.sh"
cd "$HOME"
if [[ ! -d "$ACME_HOME" ]]; then
    echo -e "${green}Installing acme.sh...${nc}"
    wget -q -O acme.sh https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh
    bash acme.sh --install
    rm -f acme.sh
fi
cd "$ACME_HOME"

# ------------------------------------------
# Install Cloudflare DNS hook
# ------------------------------------------
mkdir -p "$ACME_HOME/dnsapi"
if [[ ! -f "$ACME_HOME/dnsapi/dns_cf.sh" ]]; then
    echo -e "${green}Installing Cloudflare DNS API hook...${nc}"
    wget -O "$ACME_HOME/dnsapi/dns_cf.sh" https://raw.githubusercontent.com/acmesh-official/acme.sh/master/dnsapi/dns_cf.sh
    chmod +x "$ACME_HOME/dnsapi/dns_cf.sh"
fi

# ------------------------------------------
# Register Let's Encrypt account
# ------------------------------------------
echo -e "${green}Registering ACME account with Let's Encrypt...${nc}"
retry bash acme.sh --register-account -m ssl@givps.com --server letsencrypt

# ------------------------------------------
# Issue wildcard certificate
# ------------------------------------------
echo -e "${blue}Issuing wildcard certificate for $domain ...${nc}"
retry bash acme.sh --issue --dns dns_cf -d "$domain" -d "*.$domain" --force --server letsencrypt

# ------------------------------------------
# Install certificate to /etc/xray
# ------------------------------------------
echo -e "${blue}Installing certificate...${nc}"
mkdir -p /etc/xray
retry bash acme.sh --installcert -d "$domain" \
    --fullchainpath /etc/xray/xray.crt \
    --keypath /etc/xray/xray.key \
    --reloadcmd "systemctl restart xray.service"

chmod 600 /etc/xray/xray.key

# ------------------------------------------
# Cron auto renew + log rotate
# ------------------------------------------
echo -e "${blue}Adding cron job for auto renew...${nc}"
CRON_FILE="/etc/cron.d/acme-renew"
cat > "$CRON_FILE" <<EOF
# Auto renew ACME.sh every 2 months
0 3 1 */2 * root $ACME_HOME/acme.sh --cron --home $ACME_HOME > /var/log/acme-renew.log 2>&1
# Auto log rotation for renew (max 512KB, keep 2 backups)
0 4 1 */2 * root bash -c '
if [[ -f /var/log/acme-renew.log ]]; then
  size=\$(stat -c%s /var/log/acme-renew.log)
  if (( size > 524288 )); then
    ts=\$(date +%Y%m%d-%H%M%S)
    mv /var/log/acme-renew.log /var/log/acme-renew.log.\$ts.bak
    ls -tp /var/log/acme-renew.log.*.bak 2>/dev/null | tail -n +3 | xargs -r rm --
  fi
fi'
EOF

chmod 644 "$CRON_FILE"
systemctl restart cron

echo -e "${green}✅ ACME.sh Cloudflare setup completed successfully.${nc}"
echo -e "Certificate: /etc/xray/xray.crt"
echo -e "Key        : /etc/xray/xray.key"

echo -e "${green}XRAY Core Installer${nc}"
echo -e "${yellow}Progress...${nc}"

domain=$(cat /etc/xray/domain)

# -------------------------------
# Install dependencies
# -------------------------------
echo -e "[${green}INFO{nc}] Installing dependencies..."
apt update -y
apt install -y curl socat xz-utils wget apt-transport-https gnupg lsb-release dnsutils \
cron bash-completion ntpdate chrony zip pwgen openssl netcat iptables iptables-persistent jq nginx

# -------------------------------
# Timezone & sync
# -------------------------------
echo -e "[${green}INFO{nc}] Setting timezone & syncing time..."
timedatectl set-timezone Asia/Jakarta
timedatectl set-ntp true
systemctl enable chrony --now
chronyc -a makestep

# -------------------------------
# Prepare directories
# -------------------------------
echo -e "[${green}INFO{nc}] Preparing directories..."
install -d -m 755 -o www-data -g www-data /run/xray /var/log/xray /etc/xray
touch /var/log/xray/{access.log,error.log,access2.log,error2.log}
chmod 644 /var/log/xray/*.log

# -------------------------------
# Install Xray
# -------------------------------
echo -e "[${green}INFO{nc}] Installing Xray core..."
bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data --version 1.5.6

# -------------------------------
# Create Xray config
# -------------------------------
echo -e "[${green}INFO{nc}] Generating Xray config..."
uuid=$(cat /proc/sys/kernel/random/uuid)

cat >/etc/xray/config.json <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": { "address": "127.0.0.1" },
      "tag": "api"
    },
    {
      "listen": "/run/xray/vless_ws.sock",
      "protocol": "vless",
      "settings": { "decryption": "none", "clients": [{ "id": "$uuid" }] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } }
    },
    {
      "listen": "/run/xray/vmess_ws.sock",
      "protocol": "vmess",
      "settings": { "clients": [{ "id": "$uuid", "alterId": 0 }] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } }
    },
    {
      "listen": "/run/xray/trojan_ws.sock",
      "protocol": "trojan",
      "settings": { "clients": [{ "password": "$uuid" }] },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan" } }
    },
    {
      "listen": "127.0.0.1",
      "port": 30300,
      "protocol": "shadowsocks",
      "settings": { "clients": [{ "method": "aes-128-gcm", "password": "$uuid" }], "network": "tcp,udp" },
      "streamSettings": { "network": "ws", "wsSettings": { "path": "/ssws" } }
    },
    {
      "listen": "/run/xray/vless_grpc.sock",
      "protocol": "vless",
      "settings": { "decryption": "none", "clients": [{ "id": "$uuid" }] },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "vless-grpc" } }
    },
    {
      "listen": "/run/xray/vmess_grpc.sock",
      "protocol": "vmess",
      "settings": { "clients": [{ "id": "$uuid", "alterId": 0 }] },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "vmess-grpc" } }
    },
    {
      "listen": "/run/xray/trojan_grpc.sock",
      "protocol": "trojan",
      "settings": { "clients": [{ "password": "$uuid" }] },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "trojan-grpc" } }
    },
    {
      "listen": "127.0.0.1",
      "port": 30310,
      "protocol": "shadowsocks",
      "settings": { "clients": [{ "method": "aes-128-gcm", "password": "$uuid" }], "network": "tcp,udp" },
      "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "ss-grpc" } }
    }
  ],
  "outbounds": [
    { "protocol": "freedom" },
    { "protocol": "blackhole", "tag": "blocked" }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8","10.0.0.0/8","100.64.0.0/10",
          "169.254.0.0/16","172.16.0.0/12",
          "192.168.0.0/16","198.18.0.0/15",
          "::1/128","fc00::/7","fe80::/10"
        ],
        "outboundTag": "blocked"
      },
      {
        "inboundTag": ["api"],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "type": "field",
        "outboundTag": "blocked",
        "protocol": ["bittorrent"]
      }
    ]
  },
  "policy": {
    "levels": {
      "0": { "statsUserDownlink": true, "statsUserUplink": true }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink": true,
      "statsOutboundDownlink": true
    }
  },
  "stats": {},
  "api": {
    "services": ["StatsService"],
    "tag": "api"
  }
}
EOF

# -------------------------------
# Create systemd services
# -------------------------------
echo -e "[${green}INFO{nc}] Creating systemd services..."

cat > /etc/systemd/system/xray.service << 'EOF'
[Unit]
Description=Xray Service
After=network.target nss-lookup.target

[Service]
User=www-data
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=true
PrivateTmp=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartSec=5
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/runn.service << 'EOF'
[Unit]
Description=Prepare Xray runtime directory
After=network.target
Before=xray.service

[Service]
Type=oneshot
ExecStart=/bin/mkdir -p /run/xray
ExecStartPost=/bin/chown www-data:www-data /run/xray
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# -------------------------------
# Create Nginx config with wildcard SSL
# -------------------------------
echo -e "[${green}INFO{nc}] Configuring Nginx..."
cat >/etc/nginx/conf.d/xray.conf <<EOF
# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $domain *.$domain;

    return 301 https://$host$request_uri;
}

# HTTPS server block
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name $domain *.$domain;

    root /home/vps/public_html;
    index index.html index.htm;

    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers EECDH+CHACHA20:EECDH+AES128:EECDH+AES256:!MD5;
    ssl_prefer_server_ciphers on;

    http2 on;

    # -------------------
    # WebSocket paths
    # -------------------
    location = /vless {
        proxy_redirect off;
        proxy_pass http://unix:/run/xray/vless_ws.sock;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location = /vmess {
        proxy_redirect off;
        proxy_pass http://unix:/run/xray/vmess_ws.sock;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location = /trojan {
        proxy_redirect off;
        proxy_pass http://unix:/run/xray/trojan_ws.sock;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location = /ssws {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:30300;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # -------------------
    # gRPC paths
    # -------------------
    location ^~ /vless-grpc {
        grpc_set_header X-Real-IP $remote_addr;
        grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        grpc_set_header Host $http_host;
        grpc_pass grpc://unix:/run/xray/vless_grpc.sock;
    }

    location ^~ /vmess-grpc {
        grpc_set_header X-Real-IP $remote_addr;
        grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        grpc_set_header Host $http_host;
        grpc_pass grpc://unix:/run/xray/vmess_grpc.sock;
    }

    location ^~ /trojan-grpc {
        grpc_set_header X-Real-IP $remote_addr;
        grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        grpc_set_header Host $http_host;
        grpc_pass grpc://unix:/run/xray/trojan_grpc.sock;
    }

    location ^~ /ss-grpc {
        grpc_set_header X-Real-IP $remote_addr;
        grpc_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        grpc_set_header Host $http_host;
        grpc_pass grpc://127.0.0.1:30310;
    }
}
EOF

# -------------------------------
# Enable & start services
# -------------------------------
echo -e "[${yellow}SERVICE{nc}] Reloading systemd daemon..."
systemctl daemon-reload
systemctl enable runn.service
systemctl restart runn.service
systemctl enable xray.service
systemctl restart xray.service

echo -e "[${green}INFO{nc}] Enabling and restarting Nginx..."
nginx -t
systemctl enable nginx
systemctl restart nginx

echo -e "${yellow}✅ Xray (Vless, Vmess, Trojan WS, SS) & Nginx wildcard SSL are running{nc}"


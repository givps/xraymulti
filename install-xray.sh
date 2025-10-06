#!/bin/bash
# ===============================
# XRAY Core Installer (Vmess/Vless/Trojan/Shadowsocks)
# ===============================
set -euo pipefail

# color
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
nc='\e[0m'

echo "XRAY Core Installer"
echo "Trojan"
echo "Progress..."

# ===============================
# Cek domain
# ===============================
if [ ! -f /root/domain ]; then
    echo -e "${red}ERROR${nc}: File /root/domain tidak ditemukan!"
    exit 1
fi
domain=$(cat /root/domain)

# ===============================
# Instalasi paket & setting waktu
# ===============================
echo -e "[ ${green}INFO${nc} ] Installing dependencies..."
echo -e "[ ${green}INFO${nc} ] Installing dependencies..."
apt update -y && apt install -y \
  curl socat xz-utils wget apt-transport-https gnupg lsb-release dnsutils \
  cron bash-completion ntpdate chrony zip pwgen openssl netcat iptables \
  iptables-persistent jq

# ===============================
# Setting timezone & syncing time
# ===============================
echo -e "[ ${green}INFO${nc} ] Setting timezone & syncing time..."
timedatectl set-timezone Asia/Jakarta
timedatectl set-ntp true
systemctl enable chrony --now
chronyc -a makestep

# ===============================
# Setup folder Xray & logs
# ===============================
echo -e "[ ${green}INFO${nc} ] Preparing Xray directories..."
install -d -m 755 -o www-data -g www-data /run/xray /var/log/xray /etc/xray
touch /var/log/xray/{access.log,error.log,access2.log,error2.log}
chmod 644 /var/log/xray/*.log

# ===============================
# Install Xray Core
# ===============================
echo -e "[ ${green}INFO${nc} ] Downloading & installing Xray core..."
bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data --version 1.5.6

# ===============================
# Setup Nginx
# ===============================
echo -e "[ ${green}INFO${nc} ] Resetting Nginx configuration..."
systemctl stop nginx || true
systemctl disable nginx || true
rm -f /etc/nginx/conf.d/alone.conf
mkdir -p /home/vps/public_html
chown -R www-data:www-data /home/vps/public_html
chmod 755 /home/vps/public_html

# ===============================
# Generate clean Xray config
# ===============================
echo -e "[ ${green}INFO${nc} ] Generating Xray config..."

uuid=$(cat /proc/sys/kernel/random/uuid)

# Tulis config
#!/bin/bash
uuid=$(cat /proc/sys/kernel/random/uuid)

cat > /etc/xray/config.json <<EOF
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
      "settings": {
        "decryption": "none",
        "clients": [{ "id": "$uuid" }]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/vless" }
      }
    },
    {
      "listen": "/run/xray/vmess_ws.sock",
      "protocol": "vmess",
      "settings": {
        "clients": [{ "id": "$uuid", "alterId": 0 }]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/vmess" }
      }
    },
    {
      "listen": "/run/xray/trojan_ws.sock",
      "protocol": "trojan",
      "settings": {
        "clients": [{ "password": "$uuid" }]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/trojan" }
      }
    },
    {
      "listen": "0.0.0.0",
      "port": 2083,
      "protocol": "trojan",
      "settings": {
        "clients": [{ "password": "$uuid" }],
        "fallbacks": []
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 30300,
      "protocol": "shadowsocks",
      "settings": {
        "clients": [{ "method": "aes-128-gcm", "password": "$uuid" }],
        "network": "tcp,udp"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/ssws" }
      }
    },
    {
      "listen": "/run/xray/vless_grpc.sock",
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [{ "id": "$uuid" }]
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": { "serviceName": "vless-grpc" }
      }
    },
    {
      "listen": "/run/xray/vmess_grpc.sock",
      "protocol": "vmess",
      "settings": {
        "clients": [{ "id": "$uuid", "alterId": 0 }]
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": { "serviceName": "vmess-grpc" }
      }
    },
    {
      "listen": "/run/xray/trojan_grpc.sock",
      "protocol": "trojan",
      "settings": {
        "clients": [{ "password": "$uuid" }]
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": { "serviceName": "trojan-grpc" }
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 30310,
      "protocol": "shadowsocks",
      "settings": {
        "clients": [{ "method": "aes-128-gcm", "password": "$uuid" }],
        "network": "tcp,udp"
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": { "serviceName": "ss-grpc" }
      }
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
  "stats": {},
  "api": {
    "services": ["StatsService"],
    "tag": "api"
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
  }
}
EOF

echo -e "[INFO] Removing old override directory..."
rm -rf /etc/systemd/system/xray.service.d

# ===============================
# Xray main service
# ===============================
echo -e "[INFO] Creating /etc/systemd/system/xray.service..."
cat > /etc/systemd/system/xray.service << 'EOF'
[Unit]
Description=Xray Service
Documentation=https://github.com/XTLS/Xray-core
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
RestartPreventExitStatus=23
RestartSec=5
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

# ===============================
# Runn service for preparing /var/run/xray
# ===============================
echo -e "[INFO] Creating /etc/systemd/system/runn.service..."
cat > /etc/systemd/system/runn.service << EOF
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

cat >/etc/nginx/conf.d/xray.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain *.$domain;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2 reuseport;
    listen [::]:443 ssl http2 reuseport;
    server_name $domain *.$domain;

    root /home/vps/public_html;
    index index.html index.htm;

    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers EECDH+CHACHA20:EECDH+AES128:EECDH+AES256:!MD5;
    ssl_prefer_server_ciphers on;

    # ========================
    # WebSocket Locations
    # ========================
    location = /vless {
        proxy_redirect off;
        proxy_pass http://unix:/run/xray/vless_ws.sock;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }

    location = /vmess {
        proxy_redirect off;
        proxy_pass http://unix:/run/xray/vmess_ws.sock;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }

    location = /trojan {
        proxy_redirect off;
        proxy_pass http://unix:/run/xray/trojan_ws.sock;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }

    location = /ssws {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:30300;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }

    # ========================
    # gRPC Locations
    # ========================
    location ^~ /vless-grpc {
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_set_header Host \$http_host;
        grpc_pass grpc://unix:/run/xray/vless_grpc.sock;
    }

    location ^~ /vmess-grpc {
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_set_header Host \$http_host;
        grpc_pass grpc://unix:/run/xray/vmess_grpc.sock;
    }

    location ^~ /trojan-grpc {
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_set_header Host \$http_host;
        grpc_pass grpc://unix:/run/xray/trojan_grpc.sock;
    }

    location ^~ /ss-grpc {
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        grpc_set_header Host \$http_host;
        grpc_pass grpc://127.0.0.1:30310;
    }
}
EOF

# ===============================
# Restart & Enable Services
# ===============================

echo -e "${yellow}[SERVICE]${nc} Reloading systemd daemon..."
systemctl daemon-reload

# Pastikan direktori runtime dibuat lebih dulu
echo -e "[ ${green}INFO${nc} ] Enabling and starting runn.service..."
systemctl enable runn.service >/dev/null 2>&1
systemctl restart runn.service

# Jalankan Xray setelah runn siap
echo -e "[ ${green}INFO${nc} ] Enabling and starting Xray..."
systemctl enable xray.service >/dev/null 2>&1
systemctl restart xray.service

# Reload dan restart nginx terakhir
echo -e "[ ${green}INFO${nc} ] Reloading and restarting Nginx..."
systemctl reload nginx || true
systemctl restart nginx

# ===============================
# Info services
# ===============================
yellow() { echo -e "${yellow}${*}${nc}"; }

yellow "✅ Xray (Vmess) service is running"
yellow "✅ Xray (Vless) service is running"
yellow "✅ Xray (Trojan) service is running"
yellow "✅ Xray (Shadowsocks) service is running"
yellow "✅ Nginx reverse proxy active"
yellow "✅ Wildcard SSL loaded successfully"

# ===============================
# Clean installer
# ===============================
rm -f install-xray.sh
echo -e "${green}INFO${nc}: Installation script removed successfully."


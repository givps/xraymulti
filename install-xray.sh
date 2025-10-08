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

MYIP=$(wget -qO- ipv4.icanhazip.com || curl -sS ifconfig.me)

domain=$(cat /etc/xray/domain)
sleep 1
echo -e "[ ${green}INFO${nc} ] XRAY Core Installation Begin . . . "
apt update -y
apt upgrade -y
apt install socat -y
apt install curl -y
apt install wget -y
apt install sed -y
apt install nano -y
apt install python3 -y
apt install curl socat xz-utils wget apt-transport-https gnupg gnupg2 gnupg1 dnsutils lsb-release -y 
apt install socat cron bash-completion ntpdate -y
set -e
echo -e "\n[ INFO ] Installing and configuring Chrony NTP service...\n"
# Install chrony if not present
if ! command -v chronyd >/dev/null 2>&1; then
    apt update -y >/dev/null 2>&1
    apt install -y chrony >/dev/null 2>&1
fi
# Backup old config
if [ -f /etc/chrony/chrony.conf ]; then
    cp /etc/chrony/chrony.conf /etc/chrony/chrony.conf.bak
fi
# Write new config
cat > /etc/chrony/chrony.conf <<EOF
# Chrony NTP configuration (Auto by givps)
pool 0.id.pool.ntp.org iburst
pool 1.id.pool.ntp.org iburst
pool 2.id.pool.ntp.org iburst
pool 3.id.pool.ntp.org iburst

# Additional reliable global servers
server time.google.com iburst
server time.cloudflare.com iburst
server ntp.ubuntu.com iburst

driftfile /var/lib/chrony/chrony.drift
rtcsync
makestep 1.0 3
bindcmdaddress 127.0.0.1
bindcmdaddress ::1
keyfile /etc/chrony/chrony.keys
logdir /var/log/chrony
EOF
# Ensure log directory exists
mkdir -p /var/log/chrony
# Unmask & enable chrony
systemctl unmask chrony.service >/dev/null 2>&1 || true
systemctl daemon-reload
systemctl enable chrony.service >/dev/null 2>&1
systemctl restart chrony.service
sleep 3
echo -e "\n[ INFO ] Chrony service status:\n"
systemctl --no-pager --full status chrony.service | head -n 10
echo -e "\n[ INFO ] Checking NTP synchronization sources:\n"
chronyc sources -v || echo "Chrony not responding yet. Please wait 1–2 minutes."
echo -e "\n✅ Chrony installation and configuration complete!"
echo -e "→ Config file: /etc/chrony/chrony.conf"
echo -e "→ Backup: /etc/chrony/chrony.conf.bak"
echo -e "→ Check sync: chronyc tracking\n"

apt install zip -y
apt install curl pwgen openssl netcat cron -y

mkdir -p /etc/core

# Set GitHub base URL
BASE_URL="https://github.com/dharak36/Xray-core/releases/download/v1.0.0"

# Detect system architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    FILE_NAME="xray.linux.64bit"
elif [[ "$ARCH" == "i386" || "$ARCH" == "i686" ]]; then
    FILE_NAME="xray.linux.32bit"
else
    echo "Architecture $ARCH is not supported!"
    exit 1
fi

# Download Xray Core according to architecture
wget -O /etc/core/xray "$BASE_URL/$FILE_NAME"

# Make it executable
chmod +x /etc/core/xray

# Verify installation
echo "Xray Core successfully downloaded for architecture $ARCH"

uuid=$(cat /proc/sys/kernel/random/uuid)
mkdir -p /var/log/xray

cat> /etc/xray/config.json << END
{
  "comment": "VMESS TLS",
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
  "inbounds": [
    {
      "port": 1311,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "alterId": 0,
            "level": 0,
            "email": ""
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings":
            {
              "acceptProxyProtocol": true,
              "path": "/vmess"
            }
      }
    }
  ],
    "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      },
      {
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "type": "field",
        "outboundTag": "blocked",
        "protocol": [
          "bittorrent"
        ]
      }
    ]
  },
  "stats": {},
  "api": {
    "services": [
      "StatsService"
    ],
    "tag": "api"
  },
  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  }
}
{
  "comment": "VMESS NON-TLS",
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    },
    {
     "listen": "127.0.0.1",
     "port": "23456",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "alterId": 0,
            "email": ""
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
	"security": "none",
        "wsSettings": {
          "path": "/vmess",
          "headers": {
            "Host": ""
          }
         },
        "quicSettings": {},
        "sockopt": {
          "mark": 0,
          "tcpFastOpen": true
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    }
  ],
"outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      },
      {
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "type": "field",
        "outboundTag": "blocked",
        "protocol": [
          "bittorrent"
        ]
      }
    ]
  },
  "stats": {},
  "api": {
    "services": [
      "StatsService"
    ],
    "tag": "api"
  },
  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink" : true,
      "statsOutboundDownlink" : true
    }
  }
}
{
  "comment": "VLESS TLS",
  "log": {
    "access": "/var/log/xray/access2.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
  "inbounds": [
    {
      "port": 1312,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "level": 0,
            "email": ""
          }
        ],
        "decryption": "none"
      },
	  "encryption": "none",
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings":
            {
              "acceptProxyProtocol": true,
              "path": "/vless"
            }
      }
    }
  ],
    "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      },
      {
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "type": "field",
        "outboundTag": "blocked",
        "protocol": [
          "bittorrent"
        ]
      }
    ]
  },
  "stats": {},
  "api": {
    "services": [
      "StatsService"
    ],
    "tag": "api"
  },
  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  }
}
{
  "comment": "VLESS NON-TLS",
  "log": {
    "access": "/var/log/xray/access2.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    },
    {
     "listen": "127.0.0.1",
     "port": "14016",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "level": 0,
            "email": ""
          }
        ],
        "decryption": "none"
      },
      "encryption": "none",
      "streamSettings": {
        "network": "ws",
	"security": "none",
        "wsSettings": {
          "path": "/vless",
          "headers": {
            "Host": ""
          }
         },
        "quicSettings": {},
        "sockopt": {
          "mark": 0,
          "tcpFastOpen": true
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    }
  ],
"outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      },
      {
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "type": "field",
        "outboundTag": "blocked",
        "protocol": [
          "bittorrent"
        ]
      }
    ]
  },
  "stats": {},
  "api": {
    "services": [
      "StatsService"
    ],
    "tag": "api"
  },
  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink" : true,
      "statsOutboundDownlink" : true
    }
  }
}
{
  "comment": "TROJAN TLS",
  "log": {
    "access": "/var/log/xray/access3.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
  "inbounds": [
    {
      "port": 1313,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "${uuid}",
            "level": 0,
            "email": ""
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings":
            {
              "acceptProxyProtocol": true,
              "path": "/trojan"
            }
      }
    }
  ],
    "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      },
      {
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "type": "field",
        "outboundTag": "blocked",
        "protocol": [
          "bittorrent"
        ]
      }
    ]
  },
  "stats": {},
  "api": {
    "services": [
      "StatsService"
    ],
    "tag": "api"
  },
  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  }
}
{
  "comment": "TROJAN NON TLS",
"log": {
        "access": "/var/log/xray/access3.log",
        "error": "/var/log/xray/error.log",
        "loglevel": "info"
    },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    },
    {
      "listen": "127.0.0.1",
      "port": "25432",
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "${uuid}",
            "level": 0,
            "email": ""
          }
        ],
        "decryption": "none"
      },
            "streamSettings": {
              "network": "ws",
              "security": "none",
              "wsSettings": {
                    "path": "/trojan",
                    "headers": {
                    "Host": ""
                    }
                }
            }
        }
    ],
"outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      },
      {
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "type": "field",
        "outboundTag": "blocked",
        "protocol": [
          "bittorrent"
        ]
      }
    ]
  },
  "stats": {},
  "api": {
    "services": [
      "StatsService"
    ],
    "tag": "api"
  },
  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink" : true,
      "statsOutboundDownlink" : true
    }
  }
}
END

rm -rf /etc/systemd/system/xray.service.d
rm -rf /etc/systemd/system/xray@.service.d

cat> /etc/systemd/system/xray.service << END
[Unit]
Description=XRAY-Websocket Service
Documentation=https://github.com/XTLS/Xray-core https://github.com/dharak36/Xray-core
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/etc/core/xray run -config /etc/xray/config.json
Restart=on-failure
RestartSec=3s
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target

END

cat> /etc/systemd/system/xray@.service << END
[Unit]
Description=XRAY-Websocket Service
Documentation=https://github.com/XTLS/Xray-core https://github.com/dharak36/Xray-core
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/etc/core/xray run -config /etc/xray/%i.json
Restart=on-failure
RestartSec=3s
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target

END

#nginx config
cat >/etc/nginx/conf.d/xray.conf <<EOF
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
sed -i '$ ilocation /' /etc/nginx/conf.d/xray.conf
sed -i '$ i{' /etc/nginx/conf.d/xray.conf
sed -i '$ iif ($http_upgrade != "Upgrade") {' /etc/nginx/conf.d/xray.conf
sed -i '$ irewrite /(.*) /vless break;' /etc/nginx/conf.d/xray.conf
sed -i '$ i}' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_pass http://127.0.0.1:14016;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_http_version 1.1;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Real-IP \$remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Upgrade \$http_upgrade;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Connection "upgrade";' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Host \$http_host;' /etc/nginx/conf.d/xray.conf
sed -i '$ i}' /etc/nginx/conf.d/xray.conf

sed -i '$ ilocation = /vmess' /etc/nginx/conf.d/xray.conf
sed -i '$ i{' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_pass http://127.0.0.1:23456;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_http_version 1.1;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Real-IP \$remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Upgrade \$http_upgrade;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Connection "upgrade";' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Host \$http_host;' /etc/nginx/conf.d/xray.conf
sed -i '$ i}' /etc/nginx/conf.d/xray.conf

sed -i '$ ilocation = /trojan' /etc/nginx/conf.d/xray.conf
sed -i '$ i{' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_redirect off;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_pass http://127.0.0.1:25432;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_http_version 1.1;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Real-IP \$remote_addr;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Upgrade \$http_upgrade;' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Connection "upgrade";' /etc/nginx/conf.d/xray.conf
sed -i '$ iproxy_set_header Host \$http_host;' /etc/nginx/conf.d/xray.conf
sed -i '$ i}' /etc/nginx/conf.d/xray.conf

# enable xray
echo -e "[ ${green}OK${nc} ] Restart All Service..."
systemctl daemon-reload
systemctl enable xray.service
systemctl start xray.service
systemctl restart xray.service

# enable xray vless
echo -e "[ ${green}OK${nc} ] Restarting Vless"
systemctl daemon-reload
systemctl enable xray@vless.service
systemctl start xray@vless.service
systemctl restart xray@vless.service

# enable xray vmess
echo -e "[ ${green}OK${nc} ] Restarting Vmess"
systemctl daemon-reload
systemctl enable xray@vmess.service
systemctl start xray@vmess.service
systemctl restart xray@vmess.service

# enable xray trojan
echo -e "[ ${green}OK${nc} ] Restarting Trojan"
systemctl daemon-reload
systemctl enable xray@trojan.service
systemctl start xray@trojan.service
systemctl restart xray@trojan.service

# enable service nginx
echo -e "[ ${green}OK${nc} ] Restarting Nginx"
systemctl enable nginx
systemctl start nginx
systemctl restart nginx

# Restart done
echo -e "[ ${green}OK${nc} ] Restart All Service Done..."


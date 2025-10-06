#!/bin/bash
# ==========================================
# ACME.sh Cloudflare Installer + Auto Renew
# ==========================================

set -euo pipefail

# ------------------------------------------
# Colors
# ------------------------------------------
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

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
# Cloudflare Token
# ------------------------------------------
CF_Token="GxfBrA3Ez39MdJo53EV-LiC4dM1-xn5rslR-m5Ru"
if [[ -z "$CF_Token" ]]; then
    echo -e "${yellow}[INFO]${nc} Enter your Cloudflare API Token (Global or DNS Edit Zone):"
    read -rp "Token: " CF_Token
    echo
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
cd /root/
if [[ ! -d ~/.acme.sh ]]; then
    echo -e "${green}Installing acme.sh...${nc}"
    wget -q -O acme.sh https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh
    bash acme.sh --install
    rm -f acme.sh
fi
cd ~/.acme.sh

# ------------------------------------------
# Register Let's Encrypt account
# ------------------------------------------
echo -e "${green}Registering ACME account...${nc}"
retry bash acme.sh --register-account -m ssl@givps.com --server letsencrypt

# ------------------------------------------
# Issue certificate
# ------------------------------------------
echo -e "${blue}Issuing certificate for: $domain and *.$domain ...${nc}"
retry bash acme.sh --issue --dns dns_cf -d "$domain" -d "*.$domain" --force

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
0 3 1 */2 * root /root/.acme.sh/acme.sh --cron --home /root/.acme.sh > /var/log/acme-renew.log 2>&1
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

# ------------------------------------------
# Restart Xray if not active
# ------------------------------------------
if ! systemctl is-active --quiet xray.service; then
    echo -e "${yellow}Xray service is not active, starting...${nc}"
    systemctl start xray.service
fi

# ------------------------------------------
# Write installation log
# ------------------------------------------
echo -e "ACME.sh Certificate Installer (Cloudflare)
Domain         : $domain
Certificate    : /etc/xray/xray.crt
Private Key    : /etc/xray/xray.key
ACME Log       : /var/log/acme-install.log
Renew Log      : /var/log/acme-renew.log
Cron File      : /etc/cron.d/acme-renew
Installed at   : $(date)
" >> /root/log-install.txt

# ------------------------------------------
# Finished
# ------------------------------------------
echo -e "${green}Certificate installed successfully & auto-renew enabled!${nc}"
echo -e "${blue}Domain: ${nc}$domain"
echo -e "${blue}Cert : ${nc}/etc/xray/xray.crt"
echo -e "${blue}Key  : ${nc}/etc/xray/xray.key"
echo -e "${green}Auto renew cron: ${nc}/etc/cron.d/acme-renew"
echo -e "${green}Install log: ${nc}/var/log/acme-install.log"
echo -e "${green}Renew log:   ${nc}/var/log/acme-renew.log"
# --------------------------
# Return to menu if interactive
# --------------------------
if [[ -t 0 ]] && type menu >/dev/null 2>&1; then
    echo ""
    read -n1 -s -r -p "Press any key to return to menu..."
    echo ""
    menu
fi

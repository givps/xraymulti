#!/bin/bash
# ==========================================
# VPS Initial Setup Script
# ==========================================
set -euo pipefail
IFS=$'\n\t'

# --- Check root ---
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root."
  exit 1
fi

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# --- Get VPS public IP ---
MYIP=$(curl -s ipv4.icanhazip.com)
echo -e "${green}[INFO] VPS Public IP: $MYIP${nc}"

# --- Link Hosting ---
link="raw.githubusercontent.com/givps/xraymulti/master/ssh"

# --- Ensure essential dependencies ---
echo -e "${green}[INFO] Checking essential packages...${nc}"
DEPENDENCIES=(wget curl sudo screen)
for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${ORANGE}[INFO] Installing missing dependency: $cmd${nc}"
        apt-get update -y
        apt-get install -y "$cmd"
    fi
done

# --- Setup rc-local service ---
cat > /etc/systemd/system/rc-local.service <<-END
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local
[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99
[Install]
WantedBy=multi-user.target
END

# --- Create rc.local ---
cat > /etc/rc.local <<-END
#!/bin/sh -e
# rc.local script

# --- Start BadVPN UDPGW if installed ---
if command -v badvpn-udpgw &>/dev/null; then
    screen -dmS badvpn7100 badvpn-udpgw --listen-addr 127.0.0.1:7100 --max-clients 100
    screen -dmS badvpn7200 badvpn-udpgw --listen-addr 127.0.0.1:7200 --max-clients 100
    screen -dmS badvpn7300 badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 100
fi

# --- Enable and restart services if installed ---
systemctl enable xray 2>/dev/null || true
systemctl restart xray 2>/dev/null || true
systemctl restart nginx 2>/dev/null || true
systemctl enable runn 2>/dev/null || true
systemctl restart runn 2>/dev/null || true

# --- Setup iptables rules ---
iptables -I INPUT -p udp --dport 5300 -j ACCEPT
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300

# --- Disable IPv6 ---
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6

exit 0
END

chmod +x /etc/rc.local
systemctl enable rc-local
systemctl start rc-local.service || true

# --- Set timezone GMT+7 ---
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# --- Disable AcceptEnv in SSH ---
sed -i 's/AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config
systemctl restart sshd

# --- Update & Upgrade system ---
echo -e "${green}[INFO] Updating system...${nc}"
apt update -y
apt upgrade -y
apt dist-upgrade -y

# --- Remove unused packages ---
apt-get remove --purge ufw firewalld exim4 -y || true

# --- Install essential tools ---
apt install -y wget curl net-tools ruby python3 make cmake coreutils \
rsyslog zip unzip nano sed gnupg gnupg1 bc jq apt-transport-https \
build-essential dirmngr libxml-parser-perl neofetch git lsof \
libsqlite3-dev libz-dev gcc g++ libreadline-dev zlib1g-dev \
libssl-dev dos2unix bzip2 gzip screen iftop htop

# --- Profile settings for vps user ---
useradd -m vps || true
echo "clear" >> /home/vps/.profile
echo "neofetch" >> /home/vps/.profile
chown vps:vps /home/vps/.profile

# --- Install web server ---
echo -e "${green}[INFO] Installing Nginx & PHP...${nc}"
sudo systemctl stop nginx
sudo apt remove --purge nginx nginx-full nginx-core nginx-common libnginx-mod-* -y
sudo apt autoremove -y
sudo rm -rf /etc/nginx
sudo rm -rf /var/log/nginx
sudo apt update
sudo apt install nginx-full -y

# Remove default config
rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-available/default
apt install -y php8.1 php8.1-cli php8.1-fpm php8.1-mysql php8.1-curl php8.1-gd php8.1-mbstring php8.1-xml php8.1-zip -y
sudo systemctl enable php8.1-fpm
sudo systemctl start php8.1-fpm

# Download custom config
curl -s -k https://${link}/nginx.conf -o /etc/nginx/nginx.conf
curl -s -k https://${link}/vps.conf -o /etc/nginx/conf.d/vps.conf

# --- Setup web root ---
mkdir -p /home/vps/public_html
cd /home/vps/public_html
wget -q -O index.html "https://${link}/index" || echo "Failed to download index.html"
chown -R www-data:www-data /home/vps/public_html
chmod -R g+rw /home/vps/public_html

# --- Restart services ---
systemctl restart nginx

echo -e "${green}[INFO] VPS setup completed successfully!${nc}"

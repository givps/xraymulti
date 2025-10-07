#!/bin/bash
# ==========================================
# VPS Initial Setup Script
# ==========================================
set -euo pipefail

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
apt-get remove --purge ufw firewalld -y
apt-get remove --purge exim4 -y

# --- Install essential tools ---
apt -y install wget curl

# --- Profile settings for vps user ---
apt update -y && apt install -y \
  curl socat xz-utils wget apt-transport-https gnupg lsb-release dnsutils \
  cron bash-completion ntpdate chrony zip pwgen openssl netcat iptables \
  iptables-persistent jq
echo "" >> .profile
echo "menu" >> .profile

# Remove old NGINX
echo -e "${green}[INFO] Removing old NGINX...${nc}"
sudo apt remove -y nginx nginx-common
sudo apt update -y

# install webserver
apt -y install nginx
cd
rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default
wget -O /etc/nginx/nginx.conf "https://${Server_URL}/nginx.conf"
mkdir -p /home/vps/public_html
wget -O /etc/nginx/conf.d/vps.conf "https://${Server_URL}/vps.conf"
/etc/init.d/nginx restart

# --- Setup web root ---
mkdir -p /home/vps/public_html
cd /home/vps/public_html
wget -q -O index.html "https://${link}/index" || echo "Failed to download index.html"
chown -R www-data:www-data /home/vps/public_html
chmod -R g+rw /home/vps/public_html

# install resolvconf service
apt install resolvconf -y

#start resolvconf service
systemctl start resolvconf.service
systemctl enable resolvconf.service

# remove unnecessary files
cd
apt autoclean -y
apt -y remove --purge unscd
apt-get -y --purge remove samba*;
apt-get -y --purge remove apache2*;
apt-get -y --purge remove bind9*;
apt-get -y remove sendmail*
apt autoremove -y

echo -e "[ ${green}ok${NC} ] Restarting nginx"
/etc/init.d/nginx restart >/dev/null 2>&1

echo -e "[ ${green}ok${nc} ] Restarting resolvconf"
/etc/init.d/resolvconf restart >/dev/null 2>&1

echo -e "${green}[INFO] VPS setup completed successfully!${nc}"



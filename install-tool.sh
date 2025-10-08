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
MYIP=$(wget -qO- ipv4.icanhazip.com || curl -sS ifconfig.me)
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
# nano /etc/rc.local
cat > /etc/rc.local <<-END
#!/bin/sh -e
# rc.local
# By default this script does nothing.
exit 0
END

chmod +x /etc/rc.local
systemctl enable rc-local
systemctl start rc-local.service

# --- Set timezone GMT+7 ---
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# --- Disable ipv6 ---
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sed -i '$ i\echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.local

# --- Disable AcceptEnv in SSH ---
sed -i 's/AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config

# --- Update & Upgrade system ---
echo -e "${green}[INFO] Updating system...${nc}"
apt update -y
apt upgrade -y
apt dist-upgrade -y
apt-get remove --purge ufw firewalld -y
apt-get remove --purge exim4 -y

# --- Install essential tools ---
apt -y install wget curl

# install netfilter-persistent
apt-get install netfilter-persistent

# install tool
apt-get --reinstall --fix-missing install -y bzip2 gzip coreutils make wget screen rsyslog iftop htop net-tools zip unzip wget net-tools curl nano sed screen gnupg gnupg1 bc apt-transport-https build-essential dirmngr libxml-parser-perl neofetch git lsof
echo "clear" >> .profile
echo "menu" >> .profile

# Remove old NGINX
echo -e "${green}[INFO]${nc} Removing old NGINX..."
apt remove -y nginx nginx-common
apt purge -y nginx nginx-common
apt autoremove -y
apt update -y

echo -e "${green}[INFO]${nc} Install NGINX..."
# install webserver
apt -y install nginx
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-available/default
wget -O /etc/nginx/nginx.conf "https://${link}/nginx.conf"
mkdir -p /home/vps/public_html
wget -O /etc/nginx/conf.d/vps.conf "https://${link}/vps.conf"
/etc/init.d/nginx restart

# --- Setup web root ---
mkdir -p /home/vps/public_html
cd /home/vps/public_html
wget -q -O index.html "https://${link}/index"
chown -R www-data:www-data /home/vps/public_html
chmod -R g+rw /home/vps/public_html

# setting vnstat

# install fail2ban
apt -y install fail2ban

# banner /etc/issue.net
#wget -q -O /etc/issue.net "https://${link}/issues.net" && chmod +x /etc/issue.net
#echo "Banner /etc/issue.net" >>/etc/ssh/sshd_config

# blockir torrent
iptables -A FORWARD -m string --string "get_peers" --algo bm -j DROP
iptables -A FORWARD -m string --string "announce_peer" --algo bm -j DROP
iptables -A FORWARD -m string --string "find_node" --algo bm -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent protocol" -j DROP
iptables -A FORWARD -m string --algo bm --string "peer_id=" -j DROP
iptables -A FORWARD -m string --algo bm --string ".torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce.php?passkey=" -j DROP
iptables -A FORWARD -m string --algo bm --string "torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce" -j DROP
iptables -A FORWARD -m string --algo bm --string "info_hash" -j DROP
iptables-save > /etc/iptables.up.rules
iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload

# install resolvconf service
apt install resolvconf -y

#start resolvconf service
systemctl start resolvconf.service
systemctl enable resolvconf.service

# remove unnecessary files
apt autoclean -y
apt -y remove --purge unscd
apt-get -y --purge remove samba*;
apt-get -y --purge remove apache2*;
apt-get -y --purge remove bind9*;
apt-get -y remove sendmail*
apt autoremove -y

# finishing
chown -R www-data:www-data /home/vps/public_html
sleep 1
echo -e "[ ${green}ok${nc} ] Restarting nginx"
/etc/init.d/nginx restart >/dev/null 2>&1
sleep 1
echo -e "[ ${green}ok${nc} ] Restarting fail2ban"
/etc/init.d/fail2ban restart >/dev/null 2>&1
sleep 1
echo -e "[ ${green}ok${nc} ] Restarting resolvconf"
/etc/init.d/resolvconf restart >/dev/null 2>&1
sleep 1
#echo -e "[ ${green}ok${nc} ] Restarting cron "
#/etc/init.d/cron restart >/dev/null 2>&1
#sleep 1

echo -e "${green}[INFO]${nc} Install Tool completed..."



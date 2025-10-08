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
apt-get --reinstall --fix-missing install -y bzip2 gzip coreutils wget screen rsyslog iftop htop net-tools zip unzip wget net-tools curl nano sed screen gnupg gnupg1 bc apt-transport-https build-essential dirmngr libxml-parser-perl neofetch git lsof
echo "clear" >> .profile
echo "menu" >> .profile

# Remove old NGINX
echo -e "${green}[INFO] Removing old NGINX...${nc}"
apt remove -y nginx nginx-common
apt purge -y nginx nginx-common
apt autoremove -y
apt update -y

# install webserver
apt -y install nginx
cd
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
# Detect default network interface
NET=$(ip route | grep default | awk '{print $5}')
echo "Detected network interface: $NET"
# Install dependencies
apt update
apt -y install build-essential libsqlite3-dev wget
# Download and extract vnStat 2.6
cd /root
wget -q https://github.com/vergoh/vnstat/releases/download/v2.6/vnstat-2.6.tar.gz
tar zxvf vnstat-2.6.tar.gz
cd vnstat-2.6
# Compile and install
./configure --prefix=/usr --sysconfdir=/etc
make
make install
# Clean up source
cd /root
rm -rf vnstat-2.6 vnstat-2.6.tar.gz
# Initialize database for the detected interface (vnStat 2.6 uses --create instead of -u)
vnstat --create -i $NET
# Update vnStat config with the detected interface
sed -i "s/Interface \"eth0\"/Interface \"$NET\"/g" /etc/vnstat.conf
# Set proper permissions
chown vnstat:vnstat /var/lib/vnstat -R
# Enable and restart vnStat service
systemctl enable vnstat
systemctl restart vnstat
echo "vnStat installation and setup complete for interface $NET"

# install fail2ban
apt -y install fail2ban

# Install DDOS Flate
if [ -d '/usr/local/ddos' ]; then
	echo; echo; echo "Please un-install the previous version first"
	exit 0
else
	mkdir /usr/local/ddos
fi
clear
echo; echo 'Installing DOS-Deflate 0.6'; echo
echo; echo -n 'Downloading source files...'
wget -q -O /usr/local/ddos/ddos.conf http://www.inetbase.com/scripts/ddos/ddos.conf
echo -n '.'
wget -q -O /usr/local/ddos/LICENSE http://www.inetbase.com/scripts/ddos/LICENSE
echo -n '.'
wget -q -O /usr/local/ddos/ignore.ip.list http://www.inetbase.com/scripts/ddos/ignore.ip.list
echo -n '.'
wget -q -O /usr/local/ddos/ddos.sh http://www.inetbase.com/scripts/ddos/ddos.sh
chmod 0755 /usr/local/ddos/ddos.sh
cp -s /usr/local/ddos/ddos.sh /usr/local/sbin/ddos
echo '...done'
echo; echo -n 'Creating cron to run script every minute.....(Default setting)'
/usr/local/ddos/ddos.sh --cron > /dev/null 2>&1
echo '.....done'
echo; echo 'Installation has completed.'
echo 'Config file is at /usr/local/ddos/ddos.conf'
echo 'Please send in your comments and/or suggestions to zaf@vsnl.com'

# banner /etc/issue.net
wget -q -O /etc/issue.net "https://${link}/issues.net" && chmod +x /etc/issue.net
echo "Banner /etc/issue.net" >>/etc/ssh/sshd_config

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
cd
apt autoclean -y
apt -y remove --purge unscd
apt-get -y --purge remove samba*;
apt-get -y --purge remove apache2*;
apt-get -y --purge remove bind9*;
apt-get -y remove sendmail*
apt autoremove -y

# finishing
cd
chown -R www-data:www-data /home/vps/public_html
sleep 1
echo -e "[ ${green}ok${nc} ] Restarting nginx"
/etc/init.d/nginx restart >/dev/null 2>&1
sleep 1
echo -e "[ ${green}ok${nc} ] Restarting cron "
/etc/init.d/cron restart >/dev/null 2>&1
sleep 1
echo -e "[ ${green}ok${nc} ] Restarting fail2ban"
/etc/init.d/fail2ban restart >/dev/null 2>&1
sleep 1
echo -e "[ ${green}ok${nc} ] Restarting resolvconf"
/etc/init.d/resolvconf restart >/dev/null 2>&1
sleep 1
echo -e "[ ${green}ok${nc} ] Restarting vnstat"
/etc/init.d/vnstat restart >/dev/null 2>&1
history -c
echo "unset HISTFILE" >> /etc/profile

echo -e "${green}[INFO]${nc} Install Tool completed..."



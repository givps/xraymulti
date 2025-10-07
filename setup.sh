#!/bin/bash
# ===============================
# Setup XRAY
# ===============================
set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
		echo "You need to run this script as root"
		exit 1
fi
rm -f cf
rm -f install-tool.sh
# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'
# Getting
MYIP=$(wget -qO- ipv4.icanhazip.com);
#install tool
wget https://raw.githubusercontent.com/givps/xraymulti/master/install-tool.sh && chmod +x install-tool.sh && ./install-tool.sh

# --- Create folder ---
mkdir -p /var/lib/vps

while true; do
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}          Change DOMAIN VPS     ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e "${blue} 1 ${nc} Use Random Domain"
    echo -e "${blue} 2 ${nc} Choose Your Own Domain"
    echo -e "${red}=========================================${nc}"
    read -rp "Input 1 or 2: " dns

    if [[ "$dns" == "1" ]]; then
        if wget -q https://raw.githubusercontent.com/givps/xraymulti/master/menu/cf.sh -O cf; then
            chmod +x cf
            ./cf
        else
            echo "Failed to download cf script."
            exit 1
        fi
        break
    elif [[ "$dns" == "2" ]]; then
        read -rp "Enter Your Domain: " dom
        rm -f /etc/xray/domain /var/lib/vps/ipvps.conf
        echo "IP=$dom" > /var/lib/vps/ipvps.conf
        echo "$dom" > /etc/xray/domain
        break
    else
        echo -e "${red}Invalid input! Please try again.${nc}"
        sleep 1
        clear
    fi
done

rm -f cf

echo -e "${green}Done!${nc}"

#Instal Xray
wget https://raw.githubusercontent.com/givps/xraymulti/master/install-xray.sh && chmod +x install-xray.sh && ./install-xray.sh

#install xmenu
wget https://raw.githubusercontent.com/givps/xraymulti/master/menu/install-menu.sh && chmod +x install-menu.sh && ./install-menu.sh

echo " "
echo -e "${green}Installation has been completed${nc} "
echo -e "${red}=========================================${nc}" | tee -a log-install.txt
echo -e "${blue}    XRAY Multi Port ${nc}"  | tee -a log-install.txt
echo -e "${red}=========================================${nc}"  | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "   >>> Service & Port"  | tee -a log-install.txt
echo "   - Nginx                      : 81"  | tee -a log-install.txt
echo "   - TROJAN WS TLS        : 443"  | tee -a log-install.txt
echo "   - SHADOWSOCKS WS TLS   : 443"  | tee -a log-install.txt
echo "   - VLESS WS TLS         : 443"  | tee -a log-install.txt
echo "   - VMESS WS TLS         : 443"  | tee -a log-install.txt
echo "   - TROJAN WS HTTP       : 80"  | tee -a log-install.txt
echo "   - SHADOWSOCKS WS HTTP  : 80"  | tee -a log-install.txt
echo "   - VLESS WS HTTP        : 80"  | tee -a log-install.txt
echo "   - VMESS WS HTTP        : 80"  | tee -a log-install.txt
echo "   - TROJAN GRPC          : 443"  | tee -a log-install.txt
echo "   - SHADOWSOCKS GRPC     : 443"  | tee -a log-install.txt
echo "   - VMESS GRPC           : 443"  | tee -a log-install.txt
echo "   - VLESS GRPC           : 443"  | tee -a log-install.txt
echo "   - TROJAN TCP           : 2083"  | tee -a log-install.txt
echo -e "${red}=========================================${nc}"  | tee -a log-install.txt
echo "   >>> Server Information & Other Features"  | tee -a log-install.txt
echo "   - Timezone                : Asia/Jakarta (GMT +7)"  | tee -a log-install.txt
echo "   - Fail2Ban                : [ON]"  | tee -a log-install.txt
echo "   - Dflate                  : [ON]"  | tee -a log-install.txt
echo "   - IPtables                : [ON]"  | tee -a log-install.txt
echo "   - IPv6                    : [OFF]"  | tee -a log-install.txt
echo "   - Autoreboot On 05.00 GMT +7" | tee -a log-install.txt
echo "   - Auto Delete Expired Account" | tee -a log-install.txt
echo "   - Installation Log --> /root/log-install.txt"  | tee -a log-install.txt
echo " Reboot 10 Sec"
sleep 10
rm -rf install-menu.sh
rm -rf install-xray.sh
rm -rf install-tool.sh
rm -rf setup.sh
reboot


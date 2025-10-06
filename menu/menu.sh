#!/bin/bash
# ==========================================
# Create XRAY & VPS INFORMATION 
# ==========================================
set -euo pipefail
clear

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'
IPVPS=$(wget -qO- ipv4.icanhazip.com || curl -s ifconfig.me)
domain=$(cat /etc/xray/domain)

# -------- Uptime --------
updays=$(uptime -p | grep -oP '\d+(?= day)')
uphours=$(uptime -p | grep -oP '\d+(?= hour)')
upminutes=$(uptime -p | grep -oP '\d+(?= minute)')

# -------- CPU --------
cpu_model=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^[ \t]*//')
cpu_cores=$(grep -c ^processor /proc/cpuinfo)
cpu_load=$(top -bn1 | grep "Cpu(s)" | awk '{printf "%.1f%%", $2+$4}')

# -------- RAM --------
total_ram=$(free -h | awk '/Mem:/ {print $2}')
used_ram=$(free -h | awk '/Mem:/ {print $3}')
free_ram=$(free -h | awk '/Mem:/ {print $4}')

echo -e "${red}=========================================${nc}"
echo -e "${blue}            VPS INFORMATION             ${nc}"
echo -e "${red}=========================================${nc}"
echo -e "${blue} IP     ${nc} : $IPVPS"
echo -e "${blue} Domain ${nc} : $domain"
echo -e "${blue} Uptime ${nc} : ${updays:-0} days, ${uphours:-0} hours, ${upminutes:-0} minutes"
echo -e "${blue} CPU    ${nc} : $cpu_model ($cpu_cores cores) | Load: $cpu_load"
echo -e "${blue} RAM    ${nc} : $used_ram / $total_ram | Free: $free_ram"
echo -e "${red}=========================================${nc}"
echo -e "${blue}                Xray Menu               ${nc}"
echo -e "${red}=========================================${nc}"  
echo -e "${blue} 1 ${nc}  : Create User           "
echo -e "${blue} 2 ${nc}  : Delete User Manual    "
echo -e "${blue} 3 ${nc}  : AUTO Delete Expired   "
echo -e "${blue} 4 ${nc}  : UPDATE XRAY Core      "
echo -e "${blue} 5 ${nc}  : Restart Xray          "
echo -e "${blue} 6 ${nc}  : Change DNS            "
echo -e "${blue} 7 ${nc}  : Change Domain         "
echo -e "${blue} 8 ${nc}  : Renew SSL             "
echo -e "${blue} 9 ${nc}  : Speedtest             "
echo -e "${blue} 10 ${nc} : AUTO Reboot VPS       "
echo -e "${blue} 11 ${nc} : Reboot VPS            "
echo -e "${blue} 12 ${nc} : Info                  "
echo -e "${blue} 13 ${nc} : Exit Menu             "
echo -e "${red}=========================================${nc}" 
read -p "      Select From Options [1-12 or x] :  " menu
case $menu in 
1)
create
;;
2)
delete
;;
3)
auto-delete
;;
4)
update-xray
;;
5)
restart-xray
;;
6)
change-dns
;;
7)
change-domain
;;
8)
crtxray
;;
9)
speedtest
;;
10)
auto-reboot
;;
11)
reboot
;;
12)
cat /root/log-install.txt
;;
13)
exit
;;
*)
echo "Input The Correct Number !"
;;
esac

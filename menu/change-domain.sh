#!/bin/bash
# =========================================
# Change DOMAIN
# =========================================
set -euo pipefail
clear

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

while true; do
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}          Change DOMAIN VPS     ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e "${blue} 1 ${nc} Use Random Domain"
    echo -e "${blue} 2 ${nc} Choose Your Own Domain"
    echo -e "${blue} 3 ${nc} Back to Menu"
    echo -e "${red}=========================================${nc}"
    read -rp "Input 1, 2 or 3: " dns

    if [[ "$dns" == "1" ]]; then
        if wget -q https://raw.githubusercontent.com/givps/AutoScriptXray/master/ssh/cf.sh -O cf; then
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
    elif [[ "$dns" == "3" ]]; then
        # Kembali ke menu jika fungsi menu ada
        if type menu >/dev/null 2>&1; then
            menu
        else
            echo -e "${yellow}Menu function not found. Exiting...${nc}"
        fi
        exit 0
    else
        echo -e "${red}Invalid input! Please try again.${nc}"
        sleep 1
        clear
    fi
done

rm -f cf
echo -e "${green}Done!${nc}"

# Opsi kembali ke menu setelah selesai
if type menu >/dev/null 2>&1; then
    read -n1 -s -r -p "Press any key to return to menu..."
    echo ""
    menu
fi

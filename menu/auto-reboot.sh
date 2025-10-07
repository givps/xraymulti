#!/bin/bash
# =========================================
# Name    : Auto-Reboot VPS
# =========================================
set -euo pipefail

# --- Paths ---
AUTO_REBOOT_SCRIPT="/usr/bin/auto_reboot"
REBOOT_LOG_FILE="/root/reboot-log.txt"
CRON_FILE="/etc/cron.d/auto_reboot"

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# --- Check root ---
if [ "$EUID" -ne 0 ]; then
    echo -e "${red}ERROR:${nc} Please run as root."
    exit 1
fi

# --- Ensure cron exists ---
if ! command -v cron &> /dev/null; then
    echo -e "[${yellow}INFO${nc}] Cron service not found. Installing..."
    apt update -y && apt install -y cron
    systemctl enable cron
    systemctl start cron
fi

# --- Function to restart cron ---
restart_cron() {
    echo -e "[${green}INFO${nc}] Restarting cron service..."
    if command -v systemctl >/dev/null; then
        systemctl restart cron >/dev/null 2>&1
    else
        service cron restart >/dev/null 2>&1
    fi
}

# --- Create auto-reboot script ---
if [ ! -f "$AUTO_REBOOT_SCRIPT" ]; then
    cat > "$AUTO_REBOOT_SCRIPT" <<-EOF
#!/bin/bash
# Auto-Reboot Script
date_str=\$(date +"%F")
time_str=\$(date +"%T")
echo "Server rebooted on \$date_str at \$time_str" >> "$REBOOT_LOG_FILE"
sync "$REBOOT_LOG_FILE"
/sbin/shutdown -r +1 &> /dev/null &
EOF
    chmod +x "$AUTO_REBOOT_SCRIPT"
    touch "$REBOOT_LOG_FILE"
fi

# --- Main Menu ---
while true; do
    clear
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}             AUTO-REBOOT MENU           ${nc}"
    echo -e "${red}=========================================${nc}"
    echo -e ""
    echo -e "${blue} 1 ${nc} Auto-Reboot Every 1 Hour"
    echo -e "${blue} 2 ${nc} Auto-Reboot Every 6 Hours"
    echo -e "${blue} 3 ${nc} Auto-Reboot Every 12 Hours"
    echo -e "${blue} 4 ${nc} Auto-Reboot Daily (00:00)"
    echo -e "${blue} 5 ${nc} Auto-Reboot Weekly (Sun 00:00)"
    echo -e "${blue} 6 ${nc} Auto-Reboot Monthly (1st day 00:00)"
    echo -e "${blue} 7 ${nc} Disable Auto-Reboot"
    echo -e "${blue} 8 ${nc} View Reboot Log"
    echo -e "${blue} 9 ${nc} Clear Reboot Log"
    echo -e "${blue} 0 ${nc} Back To Menu"
    echo -e ""
    echo -e "${red}=========================================${nc}"
    echo -e ""

    read -rp "Select menu option: " opt
    clear

    case "$opt" in
        1)
            [ -f "$CRON_FILE" ] && cp "$CRON_FILE" "$CRON_FILE.bak.$(date +%F-%T)"
            echo "0 * * * * root $AUTO_REBOOT_SCRIPT" > "$CRON_FILE"
            restart_cron
            echo -e "[${green}OK${nc}] Auto-Reboot set every 1 hour."
            ;;
        2)
            [ -f "$CRON_FILE" ] && cp "$CRON_FILE" "$CRON_FILE.bak.$(date +%F-%T)"
            echo "0 */6 * * * root $AUTO_REBOOT_SCRIPT" > "$CRON_FILE"
            restart_cron
            echo -e "[${green}OK${nc}] Auto-Reboot set every 6 hours."
            ;;
        3)
            [ -f "$CRON_FILE" ] && cp "$CRON_FILE" "$CRON_FILE.bak.$(date +%F-%T)"
            echo "0 */12 * * * root $AUTO_REBOOT_SCRIPT" > "$CRON_FILE"
            restart_cron
            echo -e "[${green}OK${nc}] Auto-Reboot set every 12 hours."
            ;;
        4)
            [ -f "$CRON_FILE" ] && cp "$CRON_FILE" "$CRON_FILE.bak.$(date +%F-%T)"
            echo "0 0 * * * root $AUTO_REBOOT_SCRIPT" > "$CRON_FILE"
            restart_cron
            echo -e "[${green}OK${nc}] Auto-Reboot set daily (00:00)."
            ;;
        5)
            [ -f "$CRON_FILE" ] && cp "$CRON_FILE" "$CRON_FILE.bak.$(date +%F-%T)"
            echo "0 0 * * 0 root $AUTO_REBOOT_SCRIPT" > "$CRON_FILE"
            restart_cron
            echo -e "[${green}OK${nc}] Auto-Reboot set weekly (Sunday 00:00)."
            ;;
        6)
            [ -f "$CRON_FILE" ] && cp "$CRON_FILE" "$CRON_FILE.bak.$(date +%F-%T)"
            echo "0 0 1 * * root $AUTO_REBOOT_SCRIPT" > "$CRON_FILE"
            restart_cron
            echo -e "[${green}OK${nc}] Auto-Reboot set monthly (1st day 00:00)."
            ;;
        7)
            [ -f "$CRON_FILE" ] && cp "$CRON_FILE" "$CRON_FILE.bak.$(date +%F-%T)"
            rm -f "$CRON_FILE"
            restart_cron
            echo -e "[${green}OK${nc}] Auto-Reboot disabled."
            ;;
        8)
            echo -e "${yellow}----------- REBOOT LOG -----------${nc}"
            if [ -s "$REBOOT_LOG_FILE" ]; then
                cat "$REBOOT_LOG_FILE"
            else
                echo "No reboot activity found."
            fi
            echo -e "${red}=========================================${nc}"
            ;;
        9)
            echo "" > "$REBOOT_LOG_FILE"
            echo -e "[${green}OK${nc}] Reboot log cleared."
            ;;
        0)
            if command -v menu &> /dev/null; then
                menu
            else
                exit 0
            fi
            ;;
        *)
            echo -e "[${red}ERROR${nc}] Invalid option! Select 0-9."
            sleep 1
            ;;
    esac

    if [[ "$opt" != "0" ]]; then
        echo -e ""
        read -n 1 -s -r -p "Press any key to return to the menu..."
    fi
done

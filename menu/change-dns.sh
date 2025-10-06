#!/bin/bash
# =========================================
# change dns
# =========================================
set -euo pipefail

dnsfile="/root/dns_custom" # Using a more specific filename
RESTART_SERVICE="resolvconf.service" # Primary service to restart

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# --- Functions ---

# Function to check if DNS is a valid IPv4 address
is_valid_ip() {
    local ip="$1"
    # Basic check for four octets
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    fi
    return 1
}

# Function to safely apply DNS changes
apply_dns() {
    local dns_ip="$1"
    local apply_head=0

    # 1. Handle resolv.conf symlink (systemd-resolved)
    if [ -L /etc/resolv.conf ]; then
        echo -e "${yellow}WARNING:${nc} /etc/resolv.conf is a symlink (likely systemd-resolved)."
        echo -e "         Changes may be overwritten. Using ${yellow}resolvectl${nc} if available."
        
        if command -v resolvectl >/dev/null; then
            # Set global DNS for systemd-resolved
            resolvectl dns "$(ip -o -4 route show to default | awk '{print $5}')" "$dns_ip" 2>/dev/null || true
            echo -e "[ ${green}OK${nc} ] DNS set via resolvectl."
            
            # Use /etc/resolv.conf directly only if it points to itself
            if readlink -f /etc/resolv.conf | grep -q 'resolv.conf'; then
                echo "nameserver $dns_ip" > /etc/resolv.conf
            fi
        else
            # Proceed with direct edit as a fallback
            echo "nameserver $dns_ip" > /etc/resolv.conf
        fi
        
    else
        # 2. Standard direct edit
        echo "nameserver $dns_ip" > /etc/resolv.conf
        
        # 3. Handle resolvconf service if running
        if systemctl is-active --quiet "$RESTART_SERVICE"; then
            echo "nameserver $dns_ip" > /etc/resolvconf/resolv.conf.d/head
            apply_head=1
        fi
    fi

    # 4. Save to custom file
    echo "$dns_ip" > "$dnsfile"
    
    # 5. Restart service if needed
    if [ "$apply_head" -eq 1 ]; then
        systemctl restart "$RESTART_SERVICE" 2>/dev/null || true
    fi

    echo -e "\n${green}Success:${nc} DNS ${dns_ip} applied to VPS."
    echo -e "--- Current /etc/resolv.conf ---"
    cat /etc/resolv.conf
}

# --- Menu Loop ---
while true; do
    
    clear

    # Header
    echo -e "${red}=========================================${nc}"
    echo -e "${blue}              DNS CHANGER MENU${nc}"
    echo -e "${red}=========================================${nc}"

    # Check active DNS
    UDNS="System Default/Unknown"
    if [[ -f "$dnsfile" ]]; then
        UDNS=$(cat "$dnsfile")
    fi
    
    echo -e "\n Active Custom DNS : ${blue}$UDNS${nc}"

    echo -e ""
    echo -e " [${blue}1${nc}] Change DNS (example: 1.1.1.1)"
    echo -e " [${blue}2${nc}] Reset DNS to Google (8.8.8.8)"
    echo -e " [${blue}3${nc}] Reboot after updating DNS (Recommended)"
    echo -e ""
    echo -e " [${red}0${nc}] Back To Menu"
    echo -e " [x] Exit"
    echo -e ""
    echo -e "${red}=========================================${nc}"
    echo -e ""

    read -rp " Select option [0-3, x]: " dns
    echo ""

    case "$dns" in
        1)
            clear
            read -rp " Please enter new DNS (IPv4 only): " dns1
            
            if ! is_valid_ip "$dns1"; then
                echo -e "${red}Error:${nc} Invalid DNS format. Must be an IPv4 address (e.g., 1.1.1.1)."
                sleep 1
                continue
            fi
            
            apply_dns "$dns1"
            sleep 1
            ;;
        2)
            clear
            read -rp " Reset to Google DNS (8.8.8.8)? [y/N]: " answer
            case "${answer,,}" in # Convert to lowercase for reliable matching
                y)
                    apply_dns "8.8.8.8"
                    echo -e "\n${green}INFO:${nc} DNS reset to Google (8.8.8.8)."
                    sleep 1
                    ;;
                *)
                    echo -e "\n${yellow}INFO:${nc} Operation cancelled."
                    sleep 1
                    ;;
            esac
            ;;
        3)
            clear
            echo -e "${green}INFO:${nc} Rebooting system in 3 seconds..."
            sleep 1
            reboot
            ;;
        0)
            clear
            # Call parent menu function if it exists, otherwise exit
            menu 2>/dev/null || exit 0
            ;;
        x|X)
            exit 0
            ;;
        *)
            echo -e "${red}Error:${nc} Invalid option!"
            sleep 1
            ;;
    esac
done
#!/bin/bash
# ==========================================
# Xray + Nginx + Runn Service Controller
# ==========================================

set -euo pipefail

# --- Colors ---
red='\e[1;31m'
green='\e[0;32m'
yellow='\e[1;33m'
blue='\e[1;34m'
nc='\e[0m'

# ------------------------------------------
# Log setup
# ------------------------------------------
LOG_FILE="/var/log/service-control.log"
mkdir -p /var/log
exec > >(tee -a "$LOG_FILE") 2>&1

log() { echo -e "[${yellow}$(date '+%H:%M:%S')${nc}] $*"; }
status() {
    local SERVICE=$1
    if systemctl is-active --quiet "$SERVICE"; then
        echo -e "[ ${green}OK${nc} ] $SERVICE service ${green}running${nc}"
    else
        echo -e "[ ${red}FAILED${nc} ] $SERVICE service ${red}not running${nc}"
    fi
}

# ------------------------------------------
# Restart Services
# ------------------------------------------
log "${blue}Reloading systemd daemon...${nc}"
systemctl daemon-reload

# --- Xray ---
log "${yellow}[SERVICE]${nc} Enabling & restarting Xray..."
systemctl enable xray >/dev/null 2>&1 || true
systemctl restart xray >/dev/null 2>&1 || true
status xray

# --- Nginx ---
log "${yellow}[SERVICE]${nc} Restarting Nginx..."
systemctl restart nginx >/dev/null 2>&1 || true
status nginx

# --- Runn ---
log "${yellow}[SERVICE]${nc} Enabling & restarting Runn..."
systemctl enable runn >/dev/null 2>&1 || true
systemctl restart runn >/dev/null 2>&1 || true
status runn

# ------------------------------------------
# Summary
# ------------------------------------------
echo
log "${blue}==============================${nc}"
log "${green} Service Restart Summary ${nc}"
log "${blue}==============================${nc}"
status xray
status nginx
status runn
log "${blue}==============================${nc}"

# ------------------------------------------
# Log to /root/log-restart.txt
# ------------------------------------------
RESTART_LOG="/root/log-restart.txt"
{
    echo "---------------------------------------"
    echo "Service Restart Summary - $(date)"
    echo "---------------------------------------"
    echo "Xray  : $(systemctl is-active xray)"
    echo "Nginx : $(systemctl is-active nginx)"
    echo "Runn  : $(systemctl is-active runn)"
    echo
} >> "$RESTART_LOG"

# ------------------------------------------
# Finish
# ------------------------------------------
echo
log "${green}All services processed successfully.${nc}"
log "Main log file: ${blue}$LOG_FILE${nc}"
log "Restart summary: ${blue}$RESTART_LOG${nc}"

# --- Kembali ke menu otomatis ---
if [[ -t 0 ]] && type menu >/dev/null 2>&1; then
    echo -e "\n${blue}Press any key to return to menu...${nc}"
    read -n1 -s -r
    menu
fi



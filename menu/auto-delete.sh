#!/bin/bash
# ==========================================
# Auto Clean Expired XRAY Accounts
# ==========================================
set -euo pipefail

CONFIG_FILE="/etc/xray/config.json"
LOG_FILE="/var/log/xray-expired.log"

# --------------------------
# Ensure jq is installed
# --------------------------
if ! command -v jq &>/dev/null; then
    apt install -y jq >/dev/null 2>&1 || yum install -y jq >/dev/null 2>&1
fi

# --------------------------
# Check if config exists
# --------------------------
if [[ ! -s $CONFIG_FILE ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') ❌ Xray config not found: $CONFIG_FILE" >> "$LOG_FILE"
    exit 1
fi

expired_users=()

# --------------------------
# Parse users from comments ### username YYYY-MM-DD
# --------------------------
while read -r line; do
    [[ $line =~ ^###[[:space:]]+([^[:space:]]+)[[:space:]]+([0-9]{4}-[0-9]{2}-[0-9]{2}) ]] || continue
    user="${BASH_REMATCH[1]}"
    exp="${BASH_REMATCH[2]}"

    if ! exp_sec=$(date -d "$exp" +%s 2>/dev/null); then
        continue
    fi
    now_sec=$(date +%s)

    if (( exp_sec < now_sec )); then
        expired_users+=("$user $exp")
    fi
done < "$CONFIG_FILE"

# --------------------------
# Remove expired users
# --------------------------
if [[ ${#expired_users[@]} -gt 0 ]]; then
    echo "🧹 Removing expired users..."
    for u in "${expired_users[@]}"; do
        username="${u%% *}"
        exp="${u#* }"

        tmpfile=$(mktemp)
        trap 'rm -f "$tmpfile"' EXIT
        jq --arg user "$username" '
          .inbounds |= map(
            if .settings? and .settings.clients? then
              .settings.clients |= map(select(.email != $user and .name != $user))
            else . end
          )
        ' "$CONFIG_FILE" > "$tmpfile" && mv "$tmpfile" "$CONFIG_FILE"
        trap - EXIT

        sed -i "/^### $username $exp/d" "$CONFIG_FILE"

        echo "$(date '+%Y-%m-%d %H:%M:%S') ✔ Removed expired user $username (expired $exp)" >> "$LOG_FILE"
    done

    if systemctl restart xray >/dev/null 2>&1; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') ✔ Xray service restarted successfully." >> "$LOG_FILE"
        echo "✔ Xray service restarted successfully."
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') ❌ Failed to restart Xray service." >> "$LOG_FILE"
        echo "❌ Failed to restart Xray service."
    fi
else
    echo "✅ No expired users found."
fi

# --------------------------
# Return to menu if interactive
# --------------------------
if [[ -t 0 ]] && type menu >/dev/null 2>&1; then
    echo ""
    read -n1 -s -r -p "Press any key to return to menu..."
    echo ""
    menu
fi

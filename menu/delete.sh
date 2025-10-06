#!/bin/bash
# ==========================================
# Manual Multi-Delete XRAY Accounts
# ==========================================
set -euo pipefail

CONFIG_FILE="/etc/xray/config.json"
LOG_FILE="/var/log/xray-expired.log"

# --------------------------
# Ensure jq is installed
# --------------------------
if ! command -v jq &>/dev/null; then
    echo "[!] Installing jq..."
    apt install -y jq >/dev/null 2>&1 || yum install -y jq >/dev/null 2>&1
fi

# --------------------------
# Check config exists
# --------------------------
if [[ ! -s $CONFIG_FILE ]]; then
    echo "❌ Xray config not found: $CONFIG_FILE"
    read -n1 -s -r -p "Press any key to return to menu..."
    echo ""
    type menu &>/dev/null && menu
    exit 1
fi

# --------------------------
# Manual delete multiple users
# --------------------------
read -rp "Input usernames to delete (space-separated, Enter to skip): " -a users_input_array

if [[ ${#users_input_array[@]} -gt 0 ]]; then
    deleted_users=()
    for user in "${users_input_array[@]}"; do
        exp=$(grep -wE "^### $user" "$CONFIG_FILE" | awk '{print $3}' | head -n1)
        if [[ -z "$exp" ]]; then
            echo "❌ User $user not found!"
            continue
        fi

        # Detect protocols
        account_types=()
        while IFS= read -r inbound; do
            if jq -e --arg user "$user" ".inbounds[$inbound].settings.clients[]? | select(.email == \$user or .name == \$user)" "$CONFIG_FILE" >/dev/null; then
                proto=$(jq -r ".inbounds[$inbound].protocol" "$CONFIG_FILE")
                account_types+=("$proto")
            fi
        done < <(jq -r '.inbounds | keys[]' "$CONFIG_FILE")

        # Remove from JSON
        tmpfile=$(mktemp)
        trap 'rm -f "$tmpfile"' EXIT
        jq --arg user "$user" '
          .inbounds |= map(
            if .settings? and .settings.clients? then
              .settings.clients |= map(select(.email != $user and .name != $user))
            else . end
          )
        ' "$CONFIG_FILE" > "$tmpfile" && mv "$tmpfile" "$CONFIG_FILE"
        trap - EXIT

        # Remove comment line
        sed -i "/^### $user $exp/d" "$CONFIG_FILE"

        echo "$(date '+%Y-%m-%d %H:%M:%S') ✔ Manually deleted user $user (expired $exp)" >> "$LOG_FILE"
        echo "✔ User $user deleted successfully. Protocols: ${account_types[*]}"
        deleted_users+=("$user")
    done

    # Restart XRAY only once
    if [[ ${#deleted_users[@]} -gt 0 ]]; then
        if systemctl restart xray >/dev/null 2>&1; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') ✔ Xray service restarted successfully after multi-delete" >> "$LOG_FILE"
            echo "✔ Xray service restarted successfully."
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') ❌ Failed to restart Xray after multi-delete" >> "$LOG_FILE"
            echo "❌ Failed to restart Xray after multi-delete."
        fi
    fi
else
    echo "No manual deletion requested."
fi

# --------------------------
# Return to menu
# --------------------------
if type menu &>/dev/null; then
    echo ""
    read -n1 -s -r -p "Press any key to return to menu..."
    echo ""
    menu
fi

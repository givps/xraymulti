#!/bin/bash
# Safe System Upgrade & Reboot Script

echo "🚀 Waiting for other apt/dpkg processes to finish..."
# Wait until locks are released
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
      fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || \
      fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
    echo "Apt/dpkg lock is in use, waiting 5 seconds..."
    sleep 5
done

echo "✅ Lock released, starting system update and upgrade..."

# Update package lists
apt update -y

# Upgrade installed packages
apt upgrade -y

# Upgrade including new dependencies / remove unnecessary packages
apt dist-upgrade -y

# Clean up unnecessary packages
apt autoremove -y
apt autoclean -y

echo "✅ Upgrade completed, rebooting system in 5 seconds..."
sleep 5
reboot

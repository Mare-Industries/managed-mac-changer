#!/usr/bin/env bash
# uninstall.sh — managed-mac-changer uninstaller
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run as root."; exit 1; }

systemctl stop    managed-mac-changer.service     2>/dev/null || true
systemctl stop    managed-mac-changer-web.service 2>/dev/null || true
systemctl disable managed-mac-changer.service     2>/dev/null || true
systemctl disable managed-mac-changer-web.service 2>/dev/null || true

rm -f /etc/systemd/system/managed-mac-changer.service
rm -f /etc/systemd/system/managed-mac-changer-web.service
rm -f /usr/local/bin/managed-mac-changer
rm -rf /opt/managed-mac-changer

# Remove backup files and log
rm -rf /var/lib/managed-mac-changer
rm -f  /var/log/managed-mac-changer.log

# Remove dedicated system user and group if they exist
if id mmc &>/dev/null; then
  userdel mmc 2>/dev/null || true
fi
if getent group mmc &>/dev/null; then
  groupdel mmc 2>/dev/null || true
fi

systemctl daemon-reload

echo "Uninstalled."
echo "Config preserved at /etc/managed-mac-changer — remove manually if desired:"
echo "  sudo rm -rf /etc/managed-mac-changer"

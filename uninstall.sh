#!/usr/bin/env bash
# uninstall.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run as root."; exit 1; }

systemctl stop  identity-randomizer.service     2>/dev/null || true
systemctl stop  identity-randomizer-web.service 2>/dev/null || true
systemctl disable identity-randomizer.service     2>/dev/null || true
systemctl disable identity-randomizer-web.service 2>/dev/null || true

rm -f /etc/systemd/system/identity-randomizer.service
rm -f /etc/systemd/system/identity-randomizer-web.service
rm -f /usr/local/bin/identity-randomizer
rm -rf /opt/identity-randomizer

systemctl daemon-reload
echo "Uninstalled. Config preserved at /etc/identity-randomizer — remove manually if desired."

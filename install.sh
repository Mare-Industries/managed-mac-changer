#!/usr/bin/env bash
# install.sh — managed-mac-changer installer
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "  Error: run as root (sudo ./install.sh)"; exit 1; }

INSTALL_DIR="/opt/managed-mac-changer"
CONFIG_DIR="/etc/managed-mac-changer"
BIN_LINK="/usr/local/bin/managed-mac-changer"
MMC_USER="mmc"

echo ""
echo "  managed-mac-changer installer"
echo "  ─────────────────────────────"

# Dependency checks
command -v python3 &>/dev/null || { echo "  Error: python3 is required."; exit 1; }
command -v ip     &>/dev/null || { echo "  Error: iproute2 is required."; exit 1; }
python3 -c "import json" 2>/dev/null || { echo "  Error: python3 json module is missing."; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Clean up partial install on error
_cleanup() {
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "  Install failed — cleaning up partial state." >&2
    rm -rf "$INSTALL_DIR"
    rm -f /etc/systemd/system/managed-mac-changer.service
    rm -f /etc/systemd/system/managed-mac-changer-web.service
    rm -f "$BIN_LINK"
  fi
}
trap _cleanup EXIT

echo "  Installing to ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR"
cp -r "${SCRIPT_DIR}/bin"     "$INSTALL_DIR/"
cp -r "${SCRIPT_DIR}/lib"     "$INSTALL_DIR/"
cp -r "${SCRIPT_DIR}/web"     "$INSTALL_DIR/"
cp -r "${SCRIPT_DIR}/systemd" "$INSTALL_DIR/"

chmod +x "${INSTALL_DIR}/bin/managed-mac-changer"

echo "  Creating config dir ${CONFIG_DIR}..."
mkdir -p "$CONFIG_DIR"
if [[ ! -f "${CONFIG_DIR}/groups.json" ]]; then
  cat > "${CONFIG_DIR}/groups.json" <<'EOF'
{
  "active_groups": ["default"],
  "excluded_groups": [],
  "groups": {
    "default": {
      "description": "Default MAC addresses",
      "macs": []
    }
  }
}
EOF
fi

# Create dedicated unprivileged system user for the web service
if ! id "$MMC_USER" &>/dev/null; then
  echo "  Creating system user '${MMC_USER}'..."
  useradd -r -s /sbin/nologin -d /nonexistent -c "managed-mac-changer web UI" "$MMC_USER"
fi

chown -R "${MMC_USER}:${MMC_USER}" "$CONFIG_DIR"
chmod 750 "$CONFIG_DIR"
chmod 640 "${CONFIG_DIR}/groups.json"

echo "  Creating backup dir /var/lib/managed-mac-changer..."
mkdir -p /var/lib/managed-mac-changer
chmod 700 /var/lib/managed-mac-changer

# Restore SELinux file contexts if applicable (Fedora/RHEL)
if command -v restorecon &>/dev/null; then
  restorecon -r "$INSTALL_DIR" "$CONFIG_DIR" /var/lib/managed-mac-changer 2>/dev/null || true
fi

# Patch install paths into systemd units
sed "s|__INSTALL_DIR__|${INSTALL_DIR}|g;s|__CONFIG_DIR__|${CONFIG_DIR}|g" \
  "${INSTALL_DIR}/systemd/managed-mac-changer.service" \
  > /etc/systemd/system/managed-mac-changer.service

sed "s|__INSTALL_DIR__|${INSTALL_DIR}|g;s|__CONFIG_DIR__|${CONFIG_DIR}|g" \
  "${INSTALL_DIR}/systemd/managed-mac-changer-web.service" \
  > /etc/systemd/system/managed-mac-changer-web.service

echo "  Linking binary..."
ln -sf "${INSTALL_DIR}/bin/managed-mac-changer" "$BIN_LINK"

systemctl daemon-reload
systemctl enable managed-mac-changer.service

echo ""
echo "  ✓ Installed successfully."
echo ""
echo "  Commands:"
echo "    sudo managed-mac-changer          # randomize now"
echo "    sudo managed-mac-changer --dry-run"
echo "    managed-mac-changer status"
echo "    managed-mac-changer web           # start web UI at http://localhost:7779"
echo ""
echo "  Boot service (randomize on every boot):"
echo "    sudo systemctl enable managed-mac-changer.service"
echo ""
echo "  Web UI service (auto-start web UI):"
echo "    sudo systemctl enable managed-mac-changer-web.service"
echo "    sudo systemctl start  managed-mac-changer-web.service"
echo ""

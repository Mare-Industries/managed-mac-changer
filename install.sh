#!/usr/bin/env bash
# install.sh — identity-randomizer installer
set -euo pipefail

INSTALL_DIR="/opt/identity-randomizer"
CONFIG_DIR="/etc/identity-randomizer"
BIN_LINK="/usr/local/bin/identity-randomizer"

echo ""
echo "  identity-randomizer installer"
echo "  ─────────────────────────────"

[[ $EUID -eq 0 ]] || { echo "  Error: run as root (sudo ./install.sh)"; exit 1; }

command -v python3 &>/dev/null || { echo "  Error: python3 is required."; exit 1; }
command -v ip     &>/dev/null || { echo "  Error: iproute2 is required."; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "  Installing to ${INSTALL_DIR}..."
mkdir -p "$INSTALL_DIR"
cp -r "${SCRIPT_DIR}/bin"     "$INSTALL_DIR/"
cp -r "${SCRIPT_DIR}/lib"     "$INSTALL_DIR/"
cp -r "${SCRIPT_DIR}/web"     "$INSTALL_DIR/"
cp -r "${SCRIPT_DIR}/systemd" "$INSTALL_DIR/"

chmod +x "${INSTALL_DIR}/bin/identity-randomizer"

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
  chmod 600 "${CONFIG_DIR}/groups.json"
fi

# Patch config dir into systemd units
sed "s|__INSTALL_DIR__|${INSTALL_DIR}|g;s|__CONFIG_DIR__|${CONFIG_DIR}|g" \
  "${INSTALL_DIR}/systemd/identity-randomizer.service" \
  > /etc/systemd/system/identity-randomizer.service

sed "s|__INSTALL_DIR__|${INSTALL_DIR}|g;s|__CONFIG_DIR__|${CONFIG_DIR}|g" \
  "${INSTALL_DIR}/systemd/identity-randomizer-web.service" \
  > /etc/systemd/system/identity-randomizer-web.service

echo "  Linking binary..."
ln -sf "${INSTALL_DIR}/bin/identity-randomizer" "$BIN_LINK"

systemctl daemon-reload
systemctl enable identity-randomizer.service

echo ""
echo "  ✓ Installed successfully."
echo ""
echo "  Commands:"
echo "    sudo identity-randomizer          # randomize now"
echo "    sudo identity-randomizer --dry-run"
echo "    identity-randomizer status"
echo "    identity-randomizer web           # start web UI at http://localhost:7779"
echo ""
echo "  Boot service (randomize on every boot):"
echo "    sudo systemctl enable identity-randomizer.service"
echo ""
echo "  Web UI service (auto-start web UI):"
echo "    sudo systemctl enable identity-randomizer-web.service"
echo "    sudo systemctl start  identity-randomizer-web.service"
echo ""

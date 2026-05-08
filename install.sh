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
  "active_groups": [
    "Atop_Technologies",
    "DLink_Printboxes",
    "EBS",
    "Gigabyte_PCs",
    "Ipads",
    "Kyocera",
    "Notebooks",
    "Samsung_Displays",
    "Unknown_30138B",
    "VMware"
  ],
  "excluded_groups": [
    "EBS"
  ],
  "groups": {
    "Atop_Technologies": {
      "description": "Atop Technologies Devices (10.10.21.x)",
      "macs": [
        "00:60:e9:21:fb:18",
        "00:60:e9:21:fb:b4",
        "00:60:e9:21:fc:4a",
        "00:60:e9:25:ec:4c",
        "00:60:e9:25:ec:bc",
        "00:60:e9:25:ed:91",
        "00:60:e9:2e:b4:81",
        "00:60:e9:2e:b4:ad"
      ]
    },
    "DLink_Printboxes": {
      "description": "D-Link Printboxes",
      "macs": [
        "6c:19:8f:b6:90:52",
        "6c:19:8f:b6:90:c6",
        "ac:f1:df:0e:7d:58"
      ]
    },
    "EBS": {
      "description": "EBS MAC addresses",
      "macs": [
        "a0:80:69:fa:8e:c6",
        "a0:80:69:fa:90:8d",
        "f4:ce:23:93:37:c6"
      ]
    },
    "Gigabyte_PCs": {
      "description": "Gigabyte PCs",
      "macs": [
        "18:c0:4d:31:11:a4",
        "18:c0:4d:31:14:8e",
        "18:c0:4d:31:16:cf",
        "18:c0:4d:31:1a:69",
        "18:c0:4d:31:1a:b5",
        "18:c0:4d:31:1a:da",
        "18:c0:4d:31:1a:e5",
        "18:c0:4d:31:1a:f7",
        "18:c0:4d:31:1b:15",
        "18:c0:4d:31:1b:b4",
        "18:c0:4d:31:1b:ee",
        "18:c0:4d:31:1b:ef",
        "18:c0:4d:31:1c:c1",
        "18:c0:4d:31:1c:f6",
        "18:c0:4d:31:20:5e",
        "18:c0:4d:53:4a:5a",
        "18:c0:4d:53:52:56",
        "18:c0:4d:53:52:d6",
        "18:c0:4d:53:53:df",
        "18:c0:4d:53:5b:4a"
      ]
    },
    "Ipads": {
      "description": "EBS iPads and Tablets",
      "macs": [
        "1c:6a:76:02:57:20",
        "1c:6a:76:09:33:7c",
        "1c:6a:76:10:4e:0e",
        "ac:bc:b5:22:fd:89",
        "ac:bc:b5:23:60:7a",
        "ac:bc:b5:24:be:51",
        "ac:bc:b5:27:7c:01",
        "ac:bc:b5:2b:c5:02",
        "ac:bc:b5:2f:19:c2",
        "ac:bc:b5:2f:ca:78",
        "ac:bc:b5:30:9d:cf",
        "ac:bc:b5:33:b7:b6",
        "ac:bc:b5:34:74:c2",
        "ac:bc:b5:37:30:3f",
        "ac:bc:b5:37:c8:66",
        "bc:bb:58:2d:28:79",
        "bc:bb:58:2d:2c:55",
        "bc:bb:58:2d:a8:ac",
        "bc:bb:58:2d:ef:7b",
        "bc:bb:58:2f:a1:83",
        "bc:bb:58:30:44:29",
        "bc:bb:58:30:74:c1",
        "bc:bb:58:31:b5:89",
        "bc:bb:58:32:4a:2a",
        "bc:bb:58:32:b6:7d",
        "bc:bb:58:33:39:f3",
        "bc:bb:58:33:ec:33",
        "bc:bb:58:35:b4:15",
        "bc:bb:58:39:9c:0b",
        "bc:bb:58:3a:73:1a",
        "bc:bb:58:3b:1a:79",
        "bc:bb:58:3b:5c:0d",
        "bc:bb:58:3f:90:43",
        "ec:73:79:b9:df:24",
        "ec:73:79:ba:26:3f",
        "ec:73:79:ba:df:24",
        "ec:73:79:bb:92:36",
        "ec:73:79:bd:f8:b4",
        "ec:73:79:c0:e7:53",
        "ec:73:79:c1:60:7c",
        "ec:73:79:c1:88:86",
        "ec:73:79:c1:8b:48",
        "ec:73:79:c2:34:d5",
        "ec:73:79:c2:ff:eb"
      ]
    },
    "Kyocera": {
      "description": "Kyocera Printer Devices",
      "macs": [
        "00:17:c8:f3:27:db",
        "00:17:c8:f3:27:e0"
      ]
    },
    "Notebooks": {
      "description": "Wireless Notebooks (sit-nb)",
      "macs": [
        "d4:f3:2d:69:ec:fe",
        "d4:f3:2d:69:f9:6f",
        "dc:97:ba:cc:c6:80",
        "dc:97:ba:cd:4e:fc",
        "dc:97:ba:cd:4f:2e",
        "dc:97:ba:cd:50:9b",
        "dc:97:ba:cd:51:b8",
        "dc:97:ba:cd:52:7b",
        "dc:97:ba:cd:52:8f",
        "dc:97:ba:cd:54:06",
        "dc:97:ba:cd:54:1a",
        "dc:97:ba:cd:5c:ad",
        "dc:97:ba:cd:5d:39",
        "dc:97:ba:cd:5d:ac",
        "dc:97:ba:cd:5e:1a",
        "dc:97:ba:cd:78:d2",
        "dc:97:ba:cd:79:59",
        "dc:97:ba:cd:79:ef"
      ]
    },
    "Samsung_Displays": {
      "description": "Samsung Display Devices",
      "macs": [
        "44:5c:e9:ff:89:97",
        "64:07:f6:14:cd:16",
        "80:8a:bd:5b:4e:f9"
      ]
    },
    "Unknown_30138B": {
      "description": "Unknown Devices with 30:13:8B prefix",
      "macs": [
        "30:13:8b:63:82:2f",
        "30:13:8b:68:dd:a1",
        "30:13:8b:68:de:34",
        "30:13:8b:68:de:3a",
        "30:13:8b:69:12:67",
        "30:13:8b:69:17:7c",
        "30:13:8b:69:18:55",
        "30:13:8b:69:1a:06",
        "30:13:8b:69:1a:3a",
        "30:13:8b:69:1a:60",
        "30:13:8b:69:1a:ec"
      ]
    },
    "VMware": {
      "description": "VMware / Server Infrastructure",
      "macs": [
        "00:0c:29:11:67:25",
        "00:0c:29:2f:cd:cc",
        "00:50:56:b3:a0:eb"
      ]
    }
  }
}
EOF
fi

# Create dedicated unprivileged system user for the web service
if ! getent group "$MMC_USER" &>/dev/null; then
  groupadd -r "$MMC_USER"
fi
if ! id "$MMC_USER" &>/dev/null; then
  echo "  Creating system user '${MMC_USER}'..."
  useradd -r -s /sbin/nologin -d /nonexistent -c "managed-mac-changer web UI" -g "$MMC_USER" "$MMC_USER"
fi

chown -R "${MMC_USER}:${MMC_USER}" "$CONFIG_DIR"
chmod 750 "$CONFIG_DIR"
chmod 660 "${CONFIG_DIR}/groups.json"

# Add the invoking user to the mmc group so they can run the web UI without root
if [[ -n "${SUDO_USER:-}" ]]; then
  echo "  Adding '${SUDO_USER}' to '${MMC_USER}' group..."
  usermod -aG "$MMC_USER" "$SUDO_USER"
fi

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

# managed-mac-changer

Randomize your Linux hostname and MAC address on every boot. Includes a web UI for managing MAC address groups.

## Features

- Randomizes hostname (RFC 1123 compliant, adjective-noun-hex format)
- Randomizes MAC address from a configurable allowlist
- MAC address **groups** — organize MACs, activate/deactivate/exclude groups
- Web UI at `http://localhost:7779` for managing groups and MACs
- NetworkManager-aware (uses `cloned-mac-address`, not just `ip link`)
- Backup and restore for both hostname and MAC
- Systemd services for boot-time randomization and web UI auto-start

## Requirements

- Linux (Fedora, Ubuntu, Debian, Arch)
- `bash`, `python3`, `iproute2`
- `NetworkManager` + `nmcli` (recommended, falls back to `ip link`)
- Root for randomization, not needed for web UI or dry-run

## Install

```bash
git clone https://github.com/Mare-Industries/managed-mac-changer.git
cd managed-mac-changer
sudo bash install.sh
```

## Usage

```bash
# Randomize both hostname and MAC
sudo managed-mac-changer

# Preview without applying
sudo managed-mac-changer --dry-run

# Randomize only MAC, using a specific group
sudo managed-mac-changer --mac-only --group home

# Restore previous hostname and MAC
sudo managed-mac-changer restore

# Show current identity
managed-mac-changer status

# Start web UI
managed-mac-changer web
# → http://localhost:7779
```

## Web UI

The web UI lets you manage MAC address groups without touching config files.

```bash
# Start manually
managed-mac-changer web

# Or enable as a persistent service
sudo systemctl enable --now managed-mac-changer-web.service
```

### Groups

- **Active** groups are included in the MAC pool for randomization
- **Excluded** groups are temporarily skipped without deactivating them
- Each group can hold any number of MAC addresses
- Use `--group NAME` on the CLI to draw only from a specific group

## Config

Config is stored at `/etc/managed-mac-changer/groups.json`. You can edit it directly or use the web UI.

```json
{
  "active_groups": ["home", "work"],
  "excluded_groups": ["work"],
  "groups": {
    "home": {
      "description": "Home network MACs",
      "macs": ["a0:80:69:fa:8e:c6", "a0:80:69:fa:90:8d"]
    },
    "work": {
      "description": "Work network MACs",
      "macs": ["f4:ce:23:93:37:c6"]
    }
  }
}
```

## Boot service

The installer enables `managed-mac-changer.service` automatically. It runs once on every boot before the network comes up.

```bash
# Check status
sudo systemctl status managed-mac-changer.service

# View logs
sudo journalctl -u managed-mac-changer.service

# Disable boot randomization
sudo systemctl disable managed-mac-changer.service
```

## Uninstall

```bash
sudo bash install.sh
# Config preserved at /etc/managed-mac-changer — remove manually if desired
```

## Security

- The web UI binds to `127.0.0.1` only — not exposed on the network. Do not pass `--host 0.0.0.0` unless you understand the risk (no authentication is required to modify groups).
- The web service runs as an unprivileged system user (`mmc`) created by the installer. Only the config directory `/etc/managed-mac-changer` is writable by that user.
- Config file and log permissions follow least-privilege (mode 640/600).
- MAC randomization requires root; the web UI and `status` subcommand do not.

## Notes

- MAC changes via NetworkManager persist across reconnects but not reboots (by design)
- Some Wi-Fi drivers enforce the hardware MAC regardless — the script will warn if this happens
- If hostname randomization hangs at boot, check `journalctl -u managed-mac-changer.service`; the service has a 30-second timeout
- If port 7779 is in use, the web service will fail to start — check with `ss -tlnp | grep 7779`

# identity-randomizer

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
git clone https://github.com/youruser/identity-randomizer.git
cd identity-randomizer
sudo ./install.sh
```

## Usage

```bash
# Randomize both hostname and MAC
sudo identity-randomizer

# Preview without applying
sudo identity-randomizer --dry-run

# Randomize only MAC, using a specific group
sudo identity-randomizer --mac-only --group home

# Restore previous hostname and MAC
sudo identity-randomizer restore

# Show current identity
identity-randomizer status

# Start web UI
identity-randomizer web
# → http://localhost:7779
```

## Web UI

The web UI lets you manage MAC address groups without touching config files.

```bash
# Start manually
identity-randomizer web

# Or enable as a persistent service
sudo systemctl enable --now identity-randomizer-web.service
```

### Groups

- **Active** groups are included in the MAC pool for randomization
- **Excluded** groups are temporarily skipped without deactivating them
- Each group can hold any number of MAC addresses
- Use `--group NAME` on the CLI to draw only from a specific group

## Config

Config is stored at `/etc/identity-randomizer/groups.json`. You can edit it directly or use the web UI.

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

The installer enables `identity-randomizer.service` automatically. It runs once on every boot before the network comes up.

```bash
# Check status
sudo systemctl status identity-randomizer.service

# View logs
sudo journalctl -u identity-randomizer.service

# Disable boot randomization
sudo systemctl disable identity-randomizer.service
```

## Uninstall

```bash
sudo ./uninstall.sh
# Config is preserved at /etc/identity-randomizer — remove manually if desired
```

## Notes

- MAC changes via NetworkManager persist across reconnects but not reboots (by design)
- Some Wi-Fi drivers enforce the hardware MAC regardless — the script will warn if this happens
- The web UI binds to `127.0.0.1` only — not exposed on the network

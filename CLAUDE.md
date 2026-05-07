# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`managed-mac-changer` is a Linux system utility that randomizes hostname and MAC address on boot for network privacy. It consists of a Bash CLI, a Python REST API server, and a vanilla JS single-page web UI.

## Running and Testing

```bash
# Run the CLI (most operations require root)
sudo ./bin/managed-mac-changer              # randomize hostname + MAC
sudo ./bin/managed-mac-changer --dry-run   # preview without applying
sudo ./bin/managed-mac-changer --group NAME
managed-mac-changer status
sudo ./bin/managed-mac-changer restore

# Start the web UI (binds to 127.0.0.1:7779)
./bin/managed-mac-changer web

# Override config dir during development
MANAGED_MAC_CHANGER_CONFIG_DIR=./dev-config ./bin/managed-mac-changer status

# Install system-wide
sudo ./install.sh

# Uninstall (removes /opt/managed-mac-changer, backups, log, mmc user)
sudo ./uninstall.sh
```

There is no automated test suite. Test by running `--dry-run` and inspecting output.

## Architecture

**Entry point**: [bin/managed-mac-changer](bin/managed-mac-changer) — parses args and dispatches to lib modules.

**Core library modules** (all sourced by the CLI):
- [lib/config.sh](lib/config.sh) — reads/writes `/etc/managed-mac-changer/groups.json` via Python for JSON handling; passes file path as an argument to Python (not via string interpolation) to avoid injection
- [lib/hostname.sh](lib/hostname.sh) — generates RFC 1123-compliant hostnames in `adjective-noun-hex` format (6 hex chars from 3 urandom bytes); replaces hostnames in `/etc/hosts` using Python `re.sub` (not sed)
- [lib/mac.sh](lib/mac.sh) — randomizes MAC addresses; prefers `nmcli cloned-mac-address` for NetworkManager persistence, falls back to `ip link`; preserves the first backup and never overwrites it

**Web layer** (`web/`):
- [web/server.py](web/server.py) — standalone Python 3 HTTP server, no external framework; serves the SPA and handles a REST JSON API; no CORS headers (same-origin only)
- [web/templates/index.html](web/templates/index.html) — single-file vanilla JS SPA; manages MAC groups via the REST API

**Config schema** at `/etc/managed-mac-changer/groups.json`:
```json
{
  "active_groups": ["home"],
  "excluded_groups": [],
  "groups": {
    "home": {"description": "...", "macs": ["aa:bb:cc:dd:ee:ff"]}
  }
}
```

**Backup locations**: `/var/lib/managed-mac-changer/{interface}.bak` (MAC), `/var/lib/managed-mac-changer/hostname.bak`

**Systemd services**: `systemd/managed-mac-changer.service` (boot randomization, 30s timeout), `systemd/managed-mac-changer-web.service` (persistent web UI, runs as `mmc` system user with `ProtectSystem=strict`)

## Key Conventions

**Bash scripts** use `set -euo pipefail`. All logging goes through `info`, `warn`, and `error` functions (defined in the CLI) that write to `/var/log/managed-mac-changer.log` (mode 600). Randomness comes from `/dev/urandom` via `od`.

**Root privilege split**: `status` and `web` subcommands run without root; actual randomization requires root. The CLI checks this explicitly.

**CONFIG_DIR**: defaults to `/etc/managed-mac-changer`; overridable via `MANAGED_MAC_CHANGER_CONFIG_DIR` env var (useful for local dev).

**MAC changes**: always prefer NetworkManager (`nmcli`) over direct `ip link` manipulation — `nmcli` survives reconnects. Some Wi-Fi drivers enforce hardware MACs and silently override software changes.

**Web API endpoints** (all JSON, bound to 127.0.0.1 only):
- `GET /api/config` — full config
- `GET /api/status` — current hostname, interface, MAC
- `POST /api/groups` — create group
- `DELETE /api/groups/{name}` — delete group
- `POST /api/groups/{name}/macs` — add MAC to group
- `DELETE /api/groups/{name}/macs/{mac}` — remove MAC
- `POST /api/groups/{name}/activate|deactivate|exclude|include` — change group state

**Web service security**: runs as `mmc` system user (created by install.sh), with `ProtectSystem=strict`, `ProtectHome=yes`, `NoNewPrivileges=yes`, `PrivateTmp=yes`. Only `/etc/managed-mac-changer` is writable.

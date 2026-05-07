#!/usr/bin/env bash
# lib/config.sh — group and config management

CONFIG_FILE="${CONFIG_DIR}/groups.json"
BACKUP_DIR="/var/lib/managed-mac-changer"
LOG_FILE="/var/log/managed-mac-changer.log"

init_log() {
  touch "$LOG_FILE" 2>/dev/null || true
  chmod 600 "$LOG_FILE" 2>/dev/null || true
}

log() {
  local level="$1"; shift
  local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
  local msg="[$ts] [$level] $*"
  if [[ -w "$LOG_FILE" ]] || [[ $EUID -eq 0 ]]; then
    echo "$msg" | tee -a "$LOG_FILE" >&2
  else
    echo "$msg" >&2
  fi
}
info()  { log "INFO " "$@"; }
warn()  { log "WARN " "$@"; }
error() { log "ERROR" "$@"; exit 1; }

# Ensure config file and backup dir exist with defaults
ensure_config() {
  mkdir -p "$BACKUP_DIR" && chmod 700 "$BACKUP_DIR" 2>/dev/null || true
  if [[ ! -f "$CONFIG_FILE" ]]; then
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat > "$CONFIG_FILE" <<'EOF'
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
    chmod 600 "$CONFIG_FILE"
  fi
}

# Get all MAC addresses from active (non-excluded) groups
get_active_macs() {
  local group_filter="${1:-}"
  ensure_config

  if [[ -n "$group_filter" ]]; then
    # Single group specified — pass paths as args to avoid shell injection
    python3 -c "
import json, sys
cfg_file, grp = sys.argv[1], sys.argv[2]
with open(cfg_file) as f:
    cfg = json.load(f)
group = cfg['groups'].get(grp)
if not group:
    sys.exit(0)
for mac in group.get('macs', []):
    print(mac)
" "$CONFIG_FILE" "$group_filter"
  else
    # All active non-excluded groups
    python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    cfg = json.load(f)
active = set(cfg.get('active_groups', []))
excluded = set(cfg.get('excluded_groups', []))
groups = cfg.get('groups', {})
macs = []
for name, group in groups.items():
    if name in active and name not in excluded:
        macs.extend(group.get('macs', []))
for mac in macs:
    print(mac)
" "$CONFIG_FILE"
  fi
}

get_active_groups() {
  ensure_config
  python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    cfg = json.load(f)
active = set(cfg.get('active_groups', []))
excluded = set(cfg.get('excluded_groups', []))
result = [g for g in active if g not in excluded]
print(', '.join(result))
" "$CONFIG_FILE"
}

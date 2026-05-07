#!/usr/bin/env bash
# lib/mac.sh — MAC address randomization for managed-mac-changer

normalize_mac() { echo "${1,,}"; }

validate_mac() {
  local mac="${1,,}"
  [[ "$mac" =~ ^([0-9a-f]{2}:){5}[0-9a-f]{2}$ ]] || { warn "Invalid MAC: ${1}"; return 1; }
  return 0
}

detect_interface() {
  local iface
  iface=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^wl' | head -1) || true
  [[ -z "$iface" ]] && \
    iface=$(ip -o link show up | awk -F': ' '{print $2}' | grep -v '^lo' | head -1) || true
  [[ -n "$iface" ]] || error "Could not auto-detect interface. Use -i INTERFACE."
  echo "$iface"
}

get_current_mac() {
  ip link show "$1" | awk '/ether/ {print $2}'
}

pick_mac() {
  local group="${1:-}"
  ensure_config

  local macs=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && macs+=("$(normalize_mac "$line")")
  done < <(get_active_macs "$group")

  [[ ${#macs[@]} -gt 0 ]] || error "No MACs found. Add some via the web UI or config file."

  local idx; idx=$(rand_int "${#macs[@]}")
  local mac="${macs[$idx]}"
  validate_mac "$mac" || error "Invalid MAC in config: ${mac}"
  echo "$mac"
}

do_randomize_mac() {
  local iface="$1"
  local group="${2:-}"

  ip link show "$iface" &>/dev/null || error "Interface '${iface}' not found."

  local current; current=$(get_current_mac "$iface")
  local new_mac; new_mac=$(pick_mac "$group")

  mkdir -p "$BACKUP_DIR" && chmod 700 "$BACKUP_DIR"
  local bak="${BACKUP_DIR}/${iface}.bak"
  if [[ ! -f "$bak" ]]; then
    install -m 600 /dev/null "$bak"
    echo "$current" > "$bak"
    info "MAC backup for ${iface}: ${current}"
  else
    info "MAC backup already exists for ${iface} — keeping original."
  fi

  info "MAC: '${current}' → '${new_mac}' on ${iface}"

  if command -v nmcli &>/dev/null && nmcli general status &>/dev/null; then
    local nm_conn
    nm_conn=$(nmcli -t -f NAME,DEVICE con show --active 2>/dev/null \
      | grep ":${iface}$" | cut -d: -f1 || true)
    if [[ -n "$nm_conn" ]]; then
      nmcli con modify "$nm_conn" wifi.cloned-mac-address "$new_mac"
      nmcli con down "$nm_conn" &>/dev/null || true
      sleep 1
      nmcli con up "$nm_conn" &>/dev/null || true
      sleep 2
      local applied; applied=$(get_current_mac "$iface")
      [[ "$applied" == "$new_mac" ]] \
        && info "MAC set to ${new_mac} on ${iface}." \
        || warn "MAC on ${iface} is ${applied} — driver may have overridden."
      return 0
    fi
  fi

  # Fallback: ip link
  ip link set "$iface" down
  ip link set "$iface" address "$new_mac"
  ip link set "$iface" up
  local applied; applied=$(get_current_mac "$iface")
  [[ "$applied" == "$new_mac" ]] \
    && info "MAC set to ${new_mac} on ${iface}." \
    || warn "MAC on ${iface} is ${applied} — driver may have overridden."
}

do_restore_mac() {
  local iface="$1"
  local bfile="${BACKUP_DIR}/${iface}.bak"
  [[ -f "$bfile" ]] || error "No MAC backup found for ${iface}."
  local old_mac; old_mac=$(cat "$bfile")
  validate_mac "$old_mac" || error "Backup MAC '${old_mac}' is invalid."

  if command -v nmcli &>/dev/null && nmcli general status &>/dev/null; then
    local nm_conn
    nm_conn=$(nmcli -t -f NAME,DEVICE con show --active 2>/dev/null \
      | grep ":${iface}$" | cut -d: -f1 || true)
    if [[ -n "$nm_conn" ]]; then
      nmcli con modify "$nm_conn" wifi.cloned-mac-address ""
      nmcli con down "$nm_conn" &>/dev/null || true
      sleep 1
      nmcli con up "$nm_conn" &>/dev/null || true
      info "MAC restored to ${old_mac} on ${iface}."
      return 0
    fi
  fi

  ip link set "$iface" down
  ip link set "$iface" address "$old_mac"
  ip link set "$iface" up
  info "MAC restored to ${old_mac} on ${iface}."
}

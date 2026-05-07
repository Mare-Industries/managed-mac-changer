#!/usr/bin/env bash
# lib/hostname.sh — hostname randomization for managed-mac-changer

readonly HOST_BACKUP_FILE="${BACKUP_DIR}/hostname.bak"
readonly MAX_HOSTNAME_LEN=63
readonly MIN_HOSTNAME_LEN=6

ADJECTIVES=(
  amber ancient arctic ashen azure binary blazing bold bronze calm
  carbon cerulean cobalt cold cosmic crimson crystal cubic dark delta
  dense digital distant dusk dusty echo elder ember empty fallen faint
  forest frozen gilded glacial glowing golden grand green grey hidden
  hollow hush indigo ink inert iron ivory jade kinetic late linear
  lone lunar marble muted nebula nimble noble north null obsidian old
  onyx opal orbital pale phantom pixel polar prism proto quiet radiant
  rapid raven rigid rugged rustic sage sandy sapphire silent silver
  slate solar solid spectral static stellar stone swift terra tidal
  tinted topaz twilight ultra umbral vast verdant violet vivid void
  winter wisp zenith
)

NOUNS=(
  anchor apex arc atom axle basin beacon blade bloom bolt bridge byte
  cache canyon cascade cavern chain chasm cipher cliff cluster comet
  core crag crater crest crux curve datum delta dome drift dune echo
  ember epoch facet fault field flare forge fractal gate glyph gorge
  harbor haven horizon hull index inlet isle kernel lagoon lance
  lattice layer ledge lens link lock locus mesa module monad node
  notch orbit origin orb peak phase pillar pivot plane plateau point
  portal prism probe pulse quartz range reef relay ridge rift root
  scalar shelf signal slab slope socket span spire stage strata stream
  stratum summit switch tether tide token trace trough tunnel vault
  vector vertex vista wave wedge zenith zone
)

rand_int() {
  local max="$1"
  local raw; raw=$(od -An -N4 -tu4 /dev/urandom | tr -d ' ')
  echo $(( raw % max ))
}

rand_element() {
  local -n _arr="$1"
  local idx; idx=$(rand_int "${#_arr[@]}")
  echo "${_arr[$idx]}"
}

rand_suffix() {
  od -An -N3 -tx1 /dev/urandom | tr -d ' \n'
}

validate_hostname() {
  local h="$1"
  [[ ${#h} -ge $MIN_HOSTNAME_LEN ]] || return 1
  [[ ${#h} -le $MAX_HOSTNAME_LEN ]] || return 1
  [[ "$h" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || return 1
  [[ "$h" =~ -- ]] && return 1
  return 0
}

generate_hostname() {
  local candidate attempts=0
  while true; do
    (( attempts++ )) || true
    candidate="$(rand_element ADJECTIVES)-$(rand_element NOUNS)-$(rand_suffix)"
    validate_hostname "$candidate" && { echo "$candidate"; return 0; }
    [[ $attempts -lt 20 ]] || error "Could not generate a valid hostname."
  done
}

get_current_hostname() {
  hostnamectl --static 2>/dev/null || hostname
}

_replace_hostname_in_hosts() {
  local old_h="$1" new_h="$2"
  [[ -f /etc/hosts ]] || return 0
  cp /etc/hosts /etc/hosts.bak
  python3 -c "
import sys, re
old, new, path = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    content = f.read()
updated = re.sub(r'\b' + re.escape(old) + r'\b', new, content, flags=re.IGNORECASE)
with open(path, 'w') as f:
    f.write(updated)
" "$old_h" "$new_h" /etc/hosts
}

do_randomize_hostname() {
  local current; current=$(get_current_hostname)
  local new; new=$(generate_hostname)

  mkdir -p "$BACKUP_DIR" && chmod 700 "$BACKUP_DIR"
  install -m 600 /dev/null "$HOST_BACKUP_FILE"
  echo "$current" > "$HOST_BACKUP_FILE"
  info "Hostname backup: '${current}'"

  info "Hostname: '${current}' → '${new}'"
  hostnamectl set-hostname "$new"
  if [[ -f /etc/hostname ]]; then
    cp /etc/hostname /etc/hostname.bak
    echo "$new" > /etc/hostname
  fi
  _replace_hostname_in_hosts "$current" "$new"
  hostname "$new"
  info "Hostname set to '${new}'."
}

do_restore_hostname() {
  [[ -f "$HOST_BACKUP_FILE" ]] || error "No hostname backup found."
  local old; old=$(cat "$HOST_BACKUP_FILE")
  validate_hostname "$old" || error "Backup hostname '${old}' is invalid."
  local current; current=$(get_current_hostname)
  info "Hostname restore: '${current}' → '${old}'"
  hostnamectl set-hostname "$old"
  [[ -f /etc/hostname ]] && echo "$old" > /etc/hostname
  _replace_hostname_in_hosts "$current" "$old"
  hostname "$old"
  info "Hostname restored to '${old}'."
}

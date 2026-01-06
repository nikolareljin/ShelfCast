#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
changes_file="$root_dir/config/system_changes.json"
config_file="/etc/dhcpcd.conf"
block_start="# SHELFCAST STATIC IP START"
block_end="# SHELFCAST STATIC IP END"

SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$root_dir/vendor/script-helpers}"
if [[ -f "$SCRIPT_HELPERS_DIR/helpers.sh" ]]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_HELPERS_DIR/helpers.sh"
  shlib_import logging
else
  echo "Missing script-helpers at $SCRIPT_HELPERS_DIR. Add git@github.com:nikolareljin/script-helpers.git" >&2
  exit 1
fi

if [[ ! -f "$changes_file" ]]; then
  log_error "No system changes file found at $changes_file"
  exit 1
fi

read_field() {
  python3 - <<PY
import json
from pathlib import Path

path = Path("$changes_file")
changes = json.loads(path.read_text(encoding="utf-8"))
static_ip = changes.get("static_ip", {})
print(static_ip.get("$1", ""))
PY
}

enabled="$(read_field enabled)"
if [[ "$enabled" != "True" && "$enabled" != "true" ]]; then
  log_warn "Static IP not enabled in system_changes.json"
  exit 1
fi

iface="$(read_field iface)"
address="$(read_field address)"
router="$(read_field router)"
dns="$(read_field dns)"

if [[ -z "$iface" || -z "$address" || -z "$router" || -z "$dns" ]]; then
  log_error "Missing static IP fields (iface/address/router/dns)."
  exit 1
fi

log_info "Backing up $config_file"
sudo cp "$config_file" "${config_file}.bak"

awk -v start="$block_start" -v end="$block_end" '
  $0==start {skip=1}
  $0==end {skip=0; next}
  !skip {print}
' "$config_file" | sudo tee "$config_file" >/dev/null

{
  echo "$block_start"
  echo "interface $iface"
  echo "static ip_address=$address"
  echo "static routers=$router"
  echo "static domain_name_servers=$dns"
  echo "$block_end"
} | sudo tee -a "$config_file" >/dev/null

log_info "Static IP block written. Reboot recommended."

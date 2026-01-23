#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$root_dir/vendor/script-helpers}"
if [[ -f "$SCRIPT_HELPERS_DIR/helpers.sh" ]]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_HELPERS_DIR/helpers.sh"
  shlib_import logging
else
  log_info() { echo "[info] $*"; }
  log_warn() { echo "[warn] $*"; }
  log_error() { echo "[error] $*"; }
fi

pi_host="${1:-}"
if [[ -z "$pi_host" ]]; then
  read -r -p "Raspberry Pi IP or hostname: " pi_host
fi
if [[ -z "$pi_host" ]]; then
  log_error "No Raspberry Pi host provided."
  exit 1
fi

bundle_dir="$root_dir/dist/pi/ShelfCast"
if [[ ! -d "$bundle_dir" ]]; then
  log_info "Bundle not found, building first."
  "$root_dir/scripts/build-pi.sh"
fi

log_info "Deploying to pi@$pi_host"
rsync -az --delete "$bundle_dir/" "pi@$pi_host:/home/pi/ShelfCast"

log_info "Running provisioning on the Pi"
ssh "pi@$pi_host" "/home/pi/ShelfCast/scripts/pi-provision.sh /home/pi/ShelfCast"

log_info "Deploy complete."

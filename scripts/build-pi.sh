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

log_info "Preparing Raspberry Pi deployment bundle"
bundle_dir="$root_dir/dist/pi"
mkdir -p "$bundle_dir"

rsync -a --delete \
  --exclude '.git' \
  --exclude 'dist' \
  --exclude 'ubuntu-test' \
  --exclude 'macos-test' \
  "$root_dir/" "$bundle_dir/ShelfCast"

log_info "Bundle ready at $bundle_dir/ShelfCast"

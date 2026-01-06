#!/usr/bin/env bash
set -euo pipefail

repo_url_file="/boot/shelfcast_repo_url.txt"
if [[ ! -f "$repo_url_file" ]]; then
  echo "Missing $repo_url_file. Create it with your git repo URL." >&2
  exit 1
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$root_dir/vendor/script-helpers}"
if [[ -f "$SCRIPT_HELPERS_DIR/helpers.sh" ]]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_HELPERS_DIR/helpers.sh"
  shlib_import logging
else
  echo "Missing script-helpers at $SCRIPT_HELPERS_DIR. Add git@github.com:nikolareljin/script-helpers.git" >&2
  exit 1
fi

repo_url="$(cat "$repo_url_file")"
log_info "Provisioning ShelfCast from $repo_url"
/home/pi/ShelfCast/scripts/pi-provision.sh "$repo_url"

log_info "If you need guided setup, run /home/pi/ShelfCast/scripts/onboarding-cli.sh"

sudo systemctl disable first-boot.service

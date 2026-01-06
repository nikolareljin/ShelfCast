#!/usr/bin/env bash
set -euo pipefail

export DISPLAY=:0
xset -dpms
xset s off
xset s noblank

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

log_info "Launching kiosk browser"
chromium-browser --noerrdialogs --disable-infobars --kiosk http://localhost:8080/onboarding

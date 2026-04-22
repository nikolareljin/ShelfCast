#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir/web-app"

SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$root_dir/vendor/script-helpers}"
if [[ -f "$SCRIPT_HELPERS_DIR/helpers.sh" ]]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_HELPERS_DIR/helpers.sh"
  shlib_import logging
else
  echo "Missing script-helpers at $SCRIPT_HELPERS_DIR. Add git@github.com:nikolareljin/script-helpers.git" >&2
  exit 1
fi

export SHELFCAST_ENV_FILE="$root_dir/config/.env"

# shellcheck disable=SC1091
source "$root_dir/scripts/web-python.sh"
require_shelfcast_web_python_3_10

if [[ ! -d .venv ]]; then
  log_info "Creating virtualenv"
  python3 -m venv .venv
fi
source .venv/bin/activate
log_info "Installing Python dependencies"
pip install -r requirements.txt

if [[ ! -f "$root_dir/config/settings.json" ]]; then
  log_info "Seeding settings.json"
  cp "$root_dir/config/settings.example.json" "$root_dir/config/settings.json"
fi

log_info "Starting ShelfCast web app"
python app.py

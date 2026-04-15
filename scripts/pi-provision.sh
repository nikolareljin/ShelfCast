#!/usr/bin/env bash
set -euo pipefail

repo_source="${1:-}"
if [[ -z "$repo_source" ]]; then
  echo "Usage: $0 <git-repo-url-or-local-path>"
  exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/web-python.sh"

sudo apt update
sudo apt install -y git python3 python3-venv python3-pip chromium-browser xserver-xorg x11-xserver-utils xinit android-tools-adb
require_shelfcast_web_python_3_10

if [[ ! -d /home/pi/ShelfCast ]]; then
  if [[ -d "$repo_source/.git" || -d "$repo_source/web-app" ]]; then
    cp -R "$repo_source" /home/pi/ShelfCast
  else
    git clone "$repo_source" /home/pi/ShelfCast
  fi
fi

cd /home/pi/ShelfCast
git submodule update --init --recursive

SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-/home/pi/ShelfCast/vendor/script-helpers}"
if [[ -f "$SCRIPT_HELPERS_DIR/helpers.sh" ]]; then
  # shellcheck disable=SC1090
  source "$SCRIPT_HELPERS_DIR/helpers.sh"
  shlib_import logging
else
  echo "Missing script-helpers at $SCRIPT_HELPERS_DIR. Ensure submodules are initialized." >&2
  exit 1
fi

log_info "Seeding config files"
if [[ ! -f config/.env ]]; then
  cp config/env.example config/.env
fi
if [[ ! -f config/settings.json ]]; then
  cp config/settings.example.json config/settings.json
fi

log_info "Starting web app"
/home/pi/ShelfCast/scripts/run-web.sh >/var/log/shelfcast-web.log 2>&1 &

log_info "Enabling kiosk service"
sudo cp /home/pi/ShelfCast/raspberry-pi/kiosk.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable kiosk.service

if [[ -t 0 ]]; then
  log_info "Launching first-boot CLI"
  /home/pi/ShelfCast/scripts/onboarding-cli.sh
else
  log_info "Run /home/pi/ShelfCast/scripts/onboarding-cli.sh to finish onboarding."
fi

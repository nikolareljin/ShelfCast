#!/usr/bin/env bash
set -euo pipefail

repo_url="${1:-}"
if [[ -z "$repo_url" ]]; then
  echo "Usage: $0 <git-repo-url>"
  exit 1
fi


sudo apt update
sudo apt install -y git python3 python3-venv python3-pip chromium-browser xserver-xorg x11-xserver-utils xinit android-tools-adb

if [[ ! -d /home/pi/ShelfCast ]]; then
  git clone "$repo_url" /home/pi/ShelfCast
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

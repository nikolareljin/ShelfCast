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

log_info "Installing host prerequisites (Ubuntu)"
"$root_dir/dev-setup/install-prerequisites.sh"

log_info "Installing Android SDK"
"$root_dir/dev-setup/install-android-sdk.sh"

if [[ -f "${ANDROID_HOME:-$HOME/Android/Sdk}/env.sh" ]]; then
  # shellcheck disable=SC1090
  source "${ANDROID_HOME:-$HOME/Android/Sdk}/env.sh"
fi

log_info "Preparing ShelfCast host web app"
(
  cd "$root_dir/web-app"
  if [[ ! -d .venv ]]; then
    log_info "Creating virtualenv"
    python3 -m venv .venv
  fi
  # shellcheck disable=SC1091
  source .venv/bin/activate
  log_info "Installing Python dependencies"
  pip install -r requirements.txt
)

if [[ ! -f "$root_dir/config/settings.json" ]]; then
  log_info "Seeding settings.json"
  cp "$root_dir/config/settings.example.json" "$root_dir/config/settings.json"
fi

log_info "Building Android APK"
"$root_dir/scripts/build-android.sh"

log_info "Provisioning Android device (ADB install)"
"$root_dir/scripts/android-provision.sh"

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

get_ip_address() {
  local ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  echo "${ip:-unknown}"
}

if ! command -v adb >/dev/null 2>&1; then
  log_error "adb not found. Install with: sudo apt install -y android-tools-adb"
  exit 1
fi

log_info "Android USB provisioning (Android 4+)"
echo "Enable USB debugging on the device:"
echo "- Settings > Developer options > USB debugging"
echo "- If Developer options are hidden: Settings > About > tap Build number 7 times"
echo ""

adb start-server >/dev/null
log_info "Waiting for device authorization over USB..."
adb wait-for-device
adb devices

apk_dir="$root_dir/config/android/apks"
mkdir -p "$apk_dir"

shopt -s nullglob
apks=("$apk_dir"/*.apk)
shopt -u nullglob

if [[ ${#apks[@]} -gt 0 ]]; then
  for apk in "${apks[@]}"; do
    log_info "Installing $(basename "$apk")"
    adb install -r "$apk"
  done
else
  log_warn "No APKs found in $apk_dir. Skipping app installs."
fi

log_info "Setting up ADB reverse for localhost access"
if adb reverse tcp:8080 tcp:8080 >/dev/null 2>&1; then
  log_info "Opening ShelfCast on the device via localhost"
  adb shell am start -a android.intent.action.VIEW -d "http://localhost:8080" >/dev/null || true
else
  ip_address="$(get_ip_address)"
  if [[ "$ip_address" != "unknown" ]]; then
    log_warn "ADB reverse failed; opening ShelfCast via host IP"
    adb shell am start -a android.intent.action.VIEW -d "http://$ip_address:8080" >/dev/null || true
  else
    log_warn "Could not detect host IP. Open http://<host-ip>:8080 manually."
  fi
fi

log_info "Android provisioning complete."

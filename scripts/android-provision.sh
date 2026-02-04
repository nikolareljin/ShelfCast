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
  ip="$(ip -o -4 addr show up scope global 2>/dev/null | awk '{print $2, $4}' | while read -r iface cidr; do
    case "$iface" in
      lo|docker*|br-*|veth*|virbr*|vmnet*|tap*|wg*|tun*)
        continue
        ;;
    esac
    echo "$cidr"
    break
  done)"
  if [[ -n "$ip" ]]; then
    echo "${ip%%/*}"
    return
  fi
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

device_url="${SHELFCAST_DEVICE_URL:-}"
if [[ -z "$device_url" ]]; then
  log_info "Setting up ADB reverse for localhost access"
  if adb reverse tcp:8080 tcp:8080 >/dev/null 2>&1; then
    device_url="http://localhost:8080"
    log_info "ADB reverse enabled"
  else
    ip_address="$(get_ip_address)"
    if [[ "$ip_address" != "unknown" ]]; then
      device_url="http://$ip_address:8080"
      log_warn "ADB reverse failed (likely unsupported on Android 2.1); using host IP."
    else
      log_warn "Could not detect host IP. Open http://<host-ip>:8080 manually."
    fi
  fi
fi

if [[ -n "$device_url" ]]; then
  log_info "Opening ShelfCast on the device: $device_url"
  adb shell am start -n com.shelfcast.nook/.MainActivity -d "$device_url" >/dev/null || true
fi

log_info "Android provisioning complete."

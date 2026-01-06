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
fi

get_ip_address() {
  local ip
  ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
  echo "${ip:-unknown}"
}

if [[ ! -t 0 ]]; then
  log_warn "Interactive terminal required. Run this over SSH or the local console."
  exit 1
fi

ip_address="$(get_ip_address)"

log_info "ShelfCast first-boot guide"
echo ""
echo "Select the display device to connect:"
echo "  1) Nook Simple Touch (Android 2)"
echo "  2) Android tablet/phone (Android 4+)"
echo ""
read -r -p "Enter choice [1-2]: " choice

case "$choice" in
  1)
    echo ""
    echo "Nook Simple Touch steps:"
    echo "- Follow the driver notes in docs/04-nook-setup.md"
    echo "- Connect the Nook and confirm touch input works"
    echo "- Open http://$ip_address:8080 in the device browser"
    ;;
  2)
    echo ""
    echo "Android 4+ steps:"
    echo "- Connect the device to the same network as the Pi"
    echo "- Open http://$ip_address:8080 in the device browser"
    echo "- Optional USB auto-provisioning:"
    echo "  ./scripts/android-provision.sh"
    echo "  (Place APKs to auto-install in config/android/apks/)"
    ;;
  *)
    log_warn "Unknown choice. You can rerun this script anytime."
    ;;
esac

echo ""
echo "From another computer, open http://$ip_address:8080 to log in and finish setup."

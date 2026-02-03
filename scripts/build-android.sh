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

apk_dir="$root_dir/config/android/apks"
mkdir -p "$apk_dir"

nook_dir="$root_dir/nook-app"
if [[ ! -d "$nook_dir" ]]; then
  log_warn "No Android project exists in this repo."
  log_info "Place built APKs in: $apk_dir"
  log_info "Then run: ./scripts/android-provision.sh"
  exit 0
fi

gradle_cmd=""
if [[ -x "$nook_dir/gradlew" ]]; then
  gradle_cmd="$nook_dir/gradlew"
elif command -v gradle >/dev/null 2>&1; then
  gradle_cmd="gradle"
  log_warn "Using system Gradle. For this project, use Gradle 6.7.1-7.0.2 with Java 8-11."
fi

if [[ -z "$gradle_cmd" ]]; then
  log_warn "Gradle not found. Install Gradle or add a gradle wrapper in nook-app."
  log_info "See nook-app/README.md for Android build prerequisites."
  exit 0
fi

log_info "Building Android APK (release)"
(cd "$nook_dir" && "$gradle_cmd" assembleRelease)

apk_path="$nook_dir/app/build/outputs/apk/release/app-release.apk"
if [[ ! -f "$apk_path" ]]; then
  log_error "APK not found at expected path: $apk_path"
  exit 1
fi

dest_apk="$apk_dir/shelfcast-nook.apk"
cp "$apk_path" "$dest_apk"
log_info "APK copied to: $dest_apk"
log_info "Then run: ./scripts/android-provision.sh"

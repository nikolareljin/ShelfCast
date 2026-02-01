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

desired_gradle_version="6.7.1"
gradle_dir="$root_dir/tools/gradle-$desired_gradle_version"
gradle_bin="$gradle_dir/bin/gradle"

version_ge() {
  local a="$1" b="$2"
  [[ "$(printf '%s\n' "$b" "$a" | sort -V | head -n1)" == "$b" ]]
}

gradle_version() {
  "$1" -v 2>/dev/null | awk '/^Gradle /{print $2; exit}'
}

ensure_gradle() {
  if [[ -x "$gradle_bin" ]]; then
    echo "$gradle_bin"
    return 0
  fi
  mkdir -p "$root_dir/tools"
  local zip_name="gradle-${desired_gradle_version}-bin.zip"
  local zip_path="$root_dir/tools/$zip_name"
  local zip_url="https://services.gradle.org/distributions/$zip_name"
  log_info "Downloading Gradle $desired_gradle_version..." >&2
  curl -fsSL "$zip_url" -o "$zip_path"
  if command -v unzip >/dev/null 2>&1; then
    unzip -q "$zip_path" -d "$root_dir/tools"
  else
    python3 - "$zip_path" "$root_dir/tools" <<'PY'
import zipfile
import sys
zip_path = sys.argv[1]
dest = sys.argv[2]
with zipfile.ZipFile(zip_path) as zf:
    zf.extractall(dest)
PY
  fi
  if [[ -x "$gradle_bin" ]]; then
    echo "$gradle_bin"
    return 0
  fi
  log_error "Failed to install Gradle $desired_gradle_version in $gradle_dir." >&2
  return 1
}

gradle_cmd=""
if [[ -x "$nook_dir/gradlew" ]]; then
  gradle_cmd="$nook_dir/gradlew"
else
  if command -v gradle >/dev/null 2>&1; then
    current_version="$(gradle_version gradle)"
    if [[ -n "$current_version" ]] && version_ge "$current_version" "$desired_gradle_version"; then
      gradle_cmd="gradle"
    else
      if ! gradle_cmd="$(ensure_gradle)"; then
        gradle_cmd=""
      fi
    fi
  else
    if ! gradle_cmd="$(ensure_gradle)"; then
      gradle_cmd=""
    fi
  fi
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

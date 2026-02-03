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

ensure_java_11() {
  java_major() {
    local version
    version="$("$1" -version 2>&1 | head -n1 | sed -E 's/.*version "([^"]+)".*/\1/')"
    version="${version#1.}"
    echo "${version%%.*}"
  }

  find_java_8() {
    local candidate
    for candidate in /usr/lib/jvm/java-8-openjdk-* /usr/lib/jvm/java-8*; do
      if [[ -x "$candidate/bin/java" ]]; then
        echo "$candidate"
        return 0
      fi
    done
    return 1
  }

  local current_java=""
  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
    current_java="$JAVA_HOME/bin/java"
  else
    current_java="$(command -v java || true)"
  fi

  if [[ -n "$current_java" ]]; then
    local current_major
    current_major="$(java_major "$current_java")"
    if [[ "$current_major" -ge 9 ]]; then
      local java8_home
      if java8_home="$(find_java_8)"; then
        export JAVA_HOME="$java8_home"
        export PATH="$JAVA_HOME/bin:$PATH"
        log_warn "Using JAVA_HOME=$JAVA_HOME (Java $current_major is too new for Android builds)."
      else
        log_warn "Java $current_major detected. Install Java 8 for Android builds."
      fi
    fi
  fi
}

ensure_java_11

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

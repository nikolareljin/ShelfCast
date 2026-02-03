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
( 
  # Ensure we use a compatible Java version for Android Gradle Plugin 4.2.2.
  java_major() {
    local version
    version="$("$1" -version 2>&1 | head -n1 | sed -E 's/.*version "([^"]+)".*/\1/')"
    version="${version#1.}"
    echo "${version%%.*}"
  }

  find_java_11() {
    local candidate
    for candidate in /usr/lib/jvm/java-11-openjdk-* /usr/lib/jvm/java-11*; do
      if [[ -x "$candidate/bin/java" ]]; then
        echo "$candidate"
        return 0
      fi
    done
    return 1
  }

  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
    current_java="$JAVA_HOME/bin/java"
  else
    current_java="$(command -v java || true)"
  fi

  current_major=""
  if [[ -n "$current_java" ]]; then
    current_major="$(java_major "$current_java")"
    if [[ "$current_major" -ge 17 ]]; then
      if java11_home="$(find_java_11)"; then
        export JAVA_HOME="$java11_home"
        export PATH="$JAVA_HOME/bin:$PATH"
        log_warn "Using JAVA_HOME=$JAVA_HOME for Gradle (Java $current_major is too new)."
      fi
    fi
  fi

  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
    current_major="$(java_major "$JAVA_HOME/bin/java")"
    if [[ "$current_major" -ge 17 ]]; then
      log_error "Java $current_major is not supported by the Android Gradle Plugin. Use Java 8-11."
      exit 1
    fi
  fi

(cd "$nook_dir" && "$gradle_cmd" assembleRelease)
)

apk_path="$nook_dir/app/build/outputs/apk/release/app-release.apk"
if [[ ! -f "$apk_path" ]]; then
  unsigned_path="$nook_dir/app/build/outputs/apk/release/app-release-unsigned.apk"
  if [[ -f "$unsigned_path" ]]; then
    apk_path="$unsigned_path"
    log_warn "Release APK is unsigned; using $apk_path"
  else
    log_error "APK not found at expected path: $apk_path"
    exit 1
  fi
fi

dest_apk="$apk_dir/shelfcast-nook.apk"
cp "$apk_path" "$dest_apk"
log_info "APK copied to: $dest_apk"
log_info "Then run: ./scripts/android-provision.sh"

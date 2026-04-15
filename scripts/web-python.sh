#!/usr/bin/env bash

require_shelfcast_web_python_3_10() {
  local current_version
  current_version="$(python3 --version 2>&1)"

  if ! python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)'; then
    if declare -F log_error >/dev/null 2>&1; then
      log_error "ShelfCast web-app requires Python 3.10 or newer. Current version: ${current_version}"
      log_error "Use a host or Raspberry Pi OS image that provides Python 3.10+ before continuing."
    else
      echo "ShelfCast web-app requires Python 3.10 or newer. Current version: ${current_version}" >&2
      echo "Use a host or Raspberry Pi OS image that provides Python 3.10+ before continuing." >&2
    fi
    exit 1
  fi
}

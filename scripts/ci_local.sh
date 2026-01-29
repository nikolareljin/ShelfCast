#!/usr/bin/env bash
# SCRIPT: ci_local.sh
# DESCRIPTION: Run local checks matching CI (ruff lint for web-app).
# USAGE: scripts/ci_local.sh [--no-install] [OPTIONS]
# PARAMETERS:
#   --no-install  Skip dependency installs.
#   -h, --help    Show this help message.
# ----------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT_HELPERS_DIR="${SCRIPT_HELPERS_DIR:-$ROOT_DIR/vendor/script-helpers}"
if [[ -f "$SCRIPT_HELPERS_DIR/helpers.sh" ]]; then
  # shellcheck disable=SC1091
  source "$SCRIPT_HELPERS_DIR/helpers.sh"
  shlib_import help logging
fi
CI_PY="$SCRIPT_HELPERS_DIR/scripts/ci_python.sh"
if [[ ! -x "$CI_PY" ]]; then
  echo "Missing script-helpers CI helper at $CI_PY. Run submodule update." >&2
  exit 1
fi

NO_INSTALL=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-install) NO_INSTALL=true; shift;;
    -h|--help)
      if declare -F show_help >/dev/null 2>&1; then
        show_help "${BASH_SOURCE[0]}"
      else
        echo "Usage: scripts/ci_local.sh [--no-install]"
      fi
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

ARGS=(--workdir "$ROOT_DIR/web-app" --requirements requirements.txt --extra-install "ruff" --test-cmd "ruff check .")
if [[ "$NO_INSTALL" == "true" ]]; then
  ARGS+=(--no-install)
fi

bash "$CI_PY" "${ARGS[@]}"

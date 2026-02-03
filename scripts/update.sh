#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log_info() { echo "[info] $*"; }
log_warn() { echo "[warn] $*"; }
log_error() { echo "[error] $*"; }

if ! command -v git >/dev/null 2>&1; then
  log_error "git not found. Install git to update submodules."
  exit 1
fi

log_info "Updating submodules"
(cd "$root_dir" && git submodule update --init --recursive)

if [[ ! -d "$root_dir/vendor/script-helpers" ]]; then
  log_error "script-helpers is still missing at $root_dir/vendor/script-helpers"
  exit 1
fi

log_info "Submodules ready"

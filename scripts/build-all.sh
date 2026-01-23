#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[info] Building Android artifacts"
"$root_dir/scripts/build-android.sh"

echo "[info] Building Raspberry Pi bundle"
"$root_dir/scripts/build-pi.sh"

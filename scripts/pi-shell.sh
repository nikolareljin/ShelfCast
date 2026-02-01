#!/usr/bin/env bash
# Quick SSH access to ShelfCast Raspberry Pi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load environment
if [[ -f "$ROOT_DIR/.env.local" ]]; then
    # shellcheck disable=SC1091
    source "$ROOT_DIR/.env.local"
fi

PI_HOST="${SHELFCAST_PI_HOST:-shelfcast-pi}"
PI_USER="${SHELFCAST_PI_USER:-pi}"
PI_PATH="${SHELFCAST_PI_PATH:-/home/pi/ShelfCast}"
SSH_KEY="${SHELFCAST_SSH_KEY:-}"

SSH_OPTS="-o StrictHostKeyChecking=accept-new"
if [[ -n "$SSH_KEY" ]]; then
    SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

# If command provided, run it; otherwise interactive shell
if [[ $# -gt 0 ]]; then
    ssh $SSH_OPTS "${PI_USER}@${PI_HOST}" "cd $PI_PATH && $*"
else
    echo "Connecting to ShelfCast Pi ($PI_HOST)..."
    ssh $SSH_OPTS -t "${PI_USER}@${PI_HOST}" "cd $PI_PATH && exec \$SHELL -l"
fi

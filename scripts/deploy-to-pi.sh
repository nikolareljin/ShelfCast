#!/usr/bin/env bash
set -euo pipefail

# Deploy ShelfCast server to Raspberry Pi via SSH
# Usage: ./deploy-to-pi.sh [--restart]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load environment from .env.local if exists
if [[ -f "$ROOT_DIR/.env.local" ]]; then
    # shellcheck disable=SC1091
    source "$ROOT_DIR/.env.local"
fi

# Configuration (override with environment variables)
PI_HOST="${SHELFCAST_PI_HOST:-shelfcast-pi}"
PI_USER="${SHELFCAST_PI_USER:-pi}"
PI_PATH="${SHELFCAST_PI_PATH:-/home/pi/ShelfCast}"
SSH_KEY="${SHELFCAST_SSH_KEY:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $*"; }

# Parse arguments
RESTART_SERVICE=false
for arg in "$@"; do
    case $arg in
        --restart)
            RESTART_SERVICE=true
            ;;
        --help|-h)
            echo "Usage: $0 [--restart]"
            echo ""
            echo "Deploy ShelfCast to Raspberry Pi via SSH"
            echo ""
            echo "Options:"
            echo "  --restart    Restart the ShelfCast service after deploy"
            echo ""
            echo "Environment variables:"
            echo "  SHELFCAST_PI_HOST    Pi hostname or IP (default: shelfcast-pi)"
            echo "  SHELFCAST_PI_USER    Pi username (default: pi)"
            echo "  SHELFCAST_PI_PATH    Install path (default: /home/pi/ShelfCast)"
            echo "  SHELFCAST_SSH_KEY    SSH key path (optional)"
            exit 0
            ;;
    esac
done

# Build SSH options
SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"
if [[ -n "$SSH_KEY" ]]; then
    SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

SSH_TARGET="${PI_USER}@${PI_HOST}"

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║      ShelfCast Deployment to Pi           ║"
echo "╚═══════════════════════════════════════════╝"
echo ""

log_info "Target: $SSH_TARGET:$PI_PATH"

# Test SSH connection
log_step "Testing SSH connection..."
if ! ssh $SSH_OPTS "$SSH_TARGET" "echo 'SSH OK'" > /dev/null 2>&1; then
    log_error "Cannot connect to $SSH_TARGET"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Verify Pi is online: ping $PI_HOST"
    echo "  2. Check SSH key: ssh-copy-id $SSH_TARGET"
    echo "  3. Set correct host: export SHELFCAST_PI_HOST=<ip>"
    exit 1
fi
log_info "SSH connection OK"

# Create target directory if needed
log_step "Ensuring target directory exists..."
ssh $SSH_OPTS "$SSH_TARGET" "mkdir -p $PI_PATH"

# Sync files
log_step "Syncing files to Pi..."
rsync -avz --delete \
    --exclude '.git' \
    --exclude '.gitmodules' \
    --exclude '.venv' \
    --exclude '__pycache__' \
    --exclude '*.pyc' \
    --exclude '.env' \
    --exclude '.env.local' \
    --exclude 'config/settings.json' \
    --exclude 'config/system_changes.json' \
    --exclude 'nook-app/app/build' \
    --exclude 'nook-app/.gradle' \
    --exclude 'nook-app/build' \
    --exclude 'node_modules' \
    -e "ssh $SSH_OPTS" \
    "$ROOT_DIR/" "${SSH_TARGET}:${PI_PATH}/"

log_info "Files synced"

# Initialize on Pi
log_step "Setting up on Pi..."
ssh $SSH_OPTS "$SSH_TARGET" << EOF
cd "$PI_PATH"

# Initialize git submodules if needed
if [[ -f .gitmodules ]] && [[ ! -d vendor/script-helpers/.git ]]; then
    echo "Initializing submodules..."
    git submodule update --init --recursive 2>/dev/null || true
fi

# Create config from examples if not exists
if [[ ! -f config/settings.json ]] && [[ -f config/settings.example.json ]]; then
    cp config/settings.example.json config/settings.json
    echo "Created config/settings.json from example"
fi

if [[ ! -f web-app/.env ]] && [[ -f config/env.example ]]; then
    cp config/env.example web-app/.env
    echo "Created web-app/.env from example"
fi

# Set up Python venv and install deps
# shellcheck disable=SC1091
source "$PI_PATH/scripts/web-python.sh"

cd web-app
require_shelfcast_web_python_3_10
if [[ ! -d .venv ]]; then
    python3 -m venv .venv
    echo "Created Python virtual environment"
fi

source .venv/bin/activate
pip install -q -r requirements.txt
echo "Python dependencies installed"
EOF

log_info "Pi setup complete"

# Restart service if requested
if [[ "$RESTART_SERVICE" == "true" ]]; then
    log_step "Restarting ShelfCast service..."
    ssh $SSH_OPTS "$SSH_TARGET" << 'EOF'
if systemctl is-active --quiet shelfcast 2>/dev/null; then
    sudo systemctl restart shelfcast
    echo "Service restarted"
else
    echo "Service not installed, starting manually..."
    cd /home/pi/ShelfCast
    ./scripts/run-web.sh &
fi
EOF
    log_info "Service restarted"
fi

echo ""
log_info "Deployment complete!"
echo ""
echo "Next steps:"
echo "  - SSH to Pi: ssh $SSH_TARGET"
echo "  - Start server: cd $PI_PATH && ./scripts/run-web.sh"
echo "  - View dashboard: http://$PI_HOST:8080"
echo ""

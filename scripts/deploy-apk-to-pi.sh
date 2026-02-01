#!/usr/bin/env bash
set -euo pipefail

# Build and deploy ShelfCast Nook APK to Raspberry Pi
# The Pi then installs it on the connected Nook via ADB

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
NOOK_APP_DIR="$ROOT_DIR/nook-app"

# Load environment
if [[ -f "$ROOT_DIR/.env.local" ]]; then
    # shellcheck disable=SC1091
    source "$ROOT_DIR/.env.local"
fi

# Configuration
PI_HOST="${SHELFCAST_PI_HOST:-shelfcast-pi}"
PI_USER="${SHELFCAST_PI_USER:-pi}"
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
SKIP_BUILD=false
INSTALL_ON_NOOK=true

for arg in "$@"; do
    case $arg in
        --skip-build)
            SKIP_BUILD=true
            ;;
        --no-install)
            INSTALL_ON_NOOK=false
            ;;
        --help|-h)
            echo "Usage: $0 [--skip-build] [--no-install]"
            echo ""
            echo "Build and deploy ShelfCast APK to Raspberry Pi"
            echo ""
            echo "Options:"
            echo "  --skip-build    Skip APK build, use existing"
            echo "  --no-install    Copy APK but don't install on Nook"
            exit 0
            ;;
    esac
done

SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"
if [[ -n "$SSH_KEY" ]]; then
    SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

SSH_TARGET="${PI_USER}@${PI_HOST}"
APK_RELEASE="$NOOK_APP_DIR/app/build/outputs/apk/release/app-release.apk"
APK_DEBUG="$NOOK_APP_DIR/app/build/outputs/apk/debug/app-debug.apk"

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║     ShelfCast APK Deployment              ║"
echo "╚═══════════════════════════════════════════╝"
echo ""

# Build APK
if [[ "$SKIP_BUILD" == "false" ]]; then
    log_step "Building APK..."

    if [[ ! -d "$NOOK_APP_DIR" ]]; then
        log_error "Nook app directory not found: $NOOK_APP_DIR"
        exit 1
    fi

    cd "$NOOK_APP_DIR"

    # Check for Gradle wrapper or system Gradle
    if [[ -f "./gradlew" ]]; then
        chmod +x ./gradlew
        ./gradlew assembleRelease assembleDebug
    elif command -v gradle &> /dev/null; then
        gradle assembleRelease assembleDebug
    else
        log_error "Gradle not found. Install Gradle or use Gradle wrapper."
        exit 1
    fi

    log_info "APK build complete"
fi

# Find APK to deploy
APK_PATH=""
if [[ -f "$APK_RELEASE" ]]; then
    APK_PATH="$APK_RELEASE"
    log_info "Using release APK"
elif [[ -f "$APK_DEBUG" ]]; then
    APK_PATH="$APK_DEBUG"
    log_warn "Release APK not found, using debug APK"
else
    log_error "No APK found. Run build first."
    exit 1
fi

log_info "APK: $APK_PATH"
log_info "Size: $(du -h "$APK_PATH" | cut -f1)"

# Test SSH connection
log_step "Testing SSH connection to Pi..."
if ! ssh $SSH_OPTS "$SSH_TARGET" "echo 'OK'" > /dev/null 2>&1; then
    log_error "Cannot connect to $SSH_TARGET"
    exit 1
fi
log_info "SSH OK"

# Copy APK to Pi
log_step "Copying APK to Pi..."
scp $SSH_OPTS "$APK_PATH" "${SSH_TARGET}:/home/${PI_USER}/shelfcast-nook.apk"
log_info "APK copied to Pi"

# Install on Nook
if [[ "$INSTALL_ON_NOOK" == "true" ]]; then
    log_step "Installing on Nook via ADB..."

    ssh $SSH_OPTS "$SSH_TARGET" << 'REMOTE_SCRIPT'
set -e

APK_PATH="/home/pi/shelfcast-nook.apk"

# Check ADB
if ! command -v adb &> /dev/null; then
    echo "[ERROR] ADB not installed on Pi. Run: sudo apt install android-tools-adb"
    exit 1
fi

# Start ADB server
adb start-server

# Check for device
echo "Checking for connected device..."
DEVICES=$(adb devices | grep -v "List" | grep -v "^$" | wc -l)

if [[ "$DEVICES" -eq 0 ]]; then
    echo "[WARN] No device connected. Connect Nook via USB and enable USB debugging."
    echo "APK saved at: $APK_PATH"
    echo ""
    echo "To install manually:"
    echo "  adb install -r $APK_PATH"
    exit 0
fi

echo "Device found:"
adb devices

# Install APK
echo "Installing APK..."
adb install -r "$APK_PATH"

# Set up port forwarding (Nook can reach Pi's server via localhost)
echo "Setting up port forwarding..."
adb reverse tcp:8080 tcp:8080

# Launch app
echo "Launching ShelfCast..."
adb shell am start -n com.shelfcast.nook/.MainActivity || true

echo ""
echo "[INFO] Installation complete!"
echo "The Nook should now display the ShelfCast dashboard."
REMOTE_SCRIPT

    log_info "APK deployed and launched on Nook"
else
    log_info "APK copied to Pi at /home/${PI_USER}/shelfcast-nook.apk"
    echo ""
    echo "To install manually on Pi:"
    echo "  adb install -r /home/${PI_USER}/shelfcast-nook.apk"
fi

echo ""
log_info "Deployment complete!"

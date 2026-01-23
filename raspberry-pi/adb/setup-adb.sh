#!/usr/bin/env bash
set -euo pipefail

# Setup ADB on Raspberry Pi for Nook Simple Touch control
# Run once after installing ShelfCast on Pi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== ADB Setup for Nook Simple Touch ==="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Install ADB if not present
if ! command -v adb &> /dev/null; then
    log_info "Installing ADB..."
    sudo apt update
    sudo apt install -y android-tools-adb
else
    log_info "ADB already installed: $(adb version | head -n1)"
fi

# Install udev rules
log_info "Installing udev rules for Nook..."
sudo cp "$SCRIPT_DIR/51-nook.rules" /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger

# Add user to plugdev group
log_info "Adding user to plugdev group..."
sudo usermod -aG plugdev "$USER" 2>/dev/null || true

# Create adb key if not exists
if [[ ! -f ~/.android/adbkey ]]; then
    log_info "Initializing ADB keys..."
    mkdir -p ~/.android
    adb start-server > /dev/null 2>&1
    adb kill-server > /dev/null 2>&1
fi

# Make scripts executable
chmod +x "$SCRIPT_DIR"/*.sh

# Create symlink for easy access
if [[ ! -L /usr/local/bin/nook-ctl ]]; then
    log_info "Creating symlink: /usr/local/bin/nook-ctl"
    sudo ln -sf "$SCRIPT_DIR/nook-ctl.sh" /usr/local/bin/nook-ctl
fi

# Create screenshots directory
mkdir -p /home/pi/screenshots

echo ""
log_info "=== Setup Complete ==="
echo ""
echo "Usage:"
echo "  nook-ctl status      # Check Nook connection"
echo "  nook-ctl dashboard   # Open ShelfCast on Nook"
echo "  nook-ctl help        # Show all commands"
echo ""
echo "Next steps:"
echo "  1. Connect Nook via USB cable"
echo "  2. Enable USB debugging on Nook:"
echo "     Settings > Applications > Development > USB debugging"
echo "  3. Run: nook-ctl status"
echo ""
log_warn "Note: You may need to log out and back in for group changes to take effect"

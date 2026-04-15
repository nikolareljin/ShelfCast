#!/usr/bin/env bash
set -euo pipefail

# Raspberry Pi Setup Script for ShelfCast
# Run this on the Pi after deploying code via SSH

echo "=== ShelfCast Raspberry Pi Setup ==="
echo ""

SHELFCAST_DIR="${SHELFCAST_DIR:-/home/pi/ShelfCast}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

require_python_3_10() {
    if ! python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)'; then
        log_warn "ShelfCast web-app requires Python 3.10 or newer. Current version: $(python3 --version 2>&1)"
        log_warn "Upgrade the Pi OS to a release that provides Python 3.10+ before continuing."
        exit 1
    fi
}

# Update system
log_info "Updating system packages..."
sudo apt update
sudo apt upgrade -y

# Install required packages
log_info "Installing required packages..."
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    android-tools-adb

require_python_3_10

# Set up Python environment
log_info "Setting up Python environment..."
cd "$SHELFCAST_DIR/web-app"
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Copy config files
if [[ ! -f "$SHELFCAST_DIR/config/settings.json" ]]; then
    cp "$SHELFCAST_DIR/config/settings.example.json" "$SHELFCAST_DIR/config/settings.json"
    log_info "Created settings.json from example"
fi

if [[ ! -f "$SHELFCAST_DIR/web-app/.env" ]]; then
    cp "$SHELFCAST_DIR/config/env.example" "$SHELFCAST_DIR/web-app/.env"
    log_info "Created .env from example"
fi

# Install systemd service
log_info "Installing systemd service..."
sudo cp "$SHELFCAST_DIR/raspberry-pi/shelfcast.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable shelfcast

# Set up ADB for Nook
log_info "Setting up ADB..."
sudo usermod -aG plugdev pi 2>/dev/null || true

# Create udev rules for Nook
sudo tee /etc/udev/rules.d/51-android.rules > /dev/null << 'EOF'
# Nook Simple Touch
SUBSYSTEM=="usb", ATTR{idVendor}=="2080", MODE="0666", GROUP="plugdev"
EOF
sudo udevadm control --reload-rules

# Start the service
log_info "Starting ShelfCast service..."
sudo systemctl start shelfcast

# Check status
sleep 2
if systemctl is-active --quiet shelfcast; then
    log_info "ShelfCast is running!"
else
    log_warn "ShelfCast service failed to start. Check: sudo journalctl -u shelfcast"
fi

# Get IP address
IP_ADDR=$(hostname -I | awk '{print $1}')

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Dashboard URL: http://$IP_ADDR:8080"
echo ""
echo "Commands:"
echo "  View logs:     sudo journalctl -u shelfcast -f"
echo "  Restart:       sudo systemctl restart shelfcast"
echo "  Stop:          sudo systemctl stop shelfcast"
echo ""
echo "To connect Nook:"
echo "  1. Connect Nook via USB"
echo "  2. Enable USB debugging on Nook"
echo "  3. Run: adb devices"
echo "  4. Run: adb install -r /home/pi/shelfcast-nook.apk"
echo ""

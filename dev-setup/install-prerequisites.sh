#!/usr/bin/env bash
set -euo pipefail

# ShelfCast Development Prerequisites Installer
# Installs all required packages on Ubuntu for ShelfCast development

echo "=== ShelfCast Development Prerequisites ==="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check if running on Ubuntu/Debian
if [[ ! -f /etc/debian_version ]]; then
    log_error "This script is designed for Ubuntu/Debian systems"
    exit 1
fi

log_info "Updating package lists..."
sudo apt update

log_info "Installing base development tools..."
sudo apt install -y \
    git \
    curl \
    wget \
    unzip \
    build-essential \
    ca-certificates

log_info "Installing Python 3..."
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv

log_info "Installing Java 11 (required for Android SDK)..."
sudo apt install -y openjdk-11-jdk

log_info "Installing ADB..."
sudo apt install -y android-tools-adb

log_info "Installing SSH client tools..."
sudo apt install -y \
    openssh-client \
    rsync \
    sshpass

log_info "Installing Gradle..."
sudo apt install -y gradle || {
    log_warn "Gradle not in apt, will use Gradle wrapper in projects"
}

# Set up udev rules for Android devices
log_info "Setting up Android USB rules..."
UDEV_RULES="/etc/udev/rules.d/51-android.rules"
if [[ ! -f "$UDEV_RULES" ]]; then
    sudo tee "$UDEV_RULES" > /dev/null << 'EOF'
# Nook Simple Touch (Barnes & Noble)
SUBSYSTEM=="usb", ATTR{idVendor}=="2080", MODE="0666", GROUP="plugdev"
# Google/Nexus devices
SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666", GROUP="plugdev"
# Samsung
SUBSYSTEM=="usb", ATTR{idVendor}=="04e8", MODE="0666", GROUP="plugdev"
# Generic Android
SUBSYSTEM=="usb", ATTR{idVendor}=="0bb4", MODE="0666", GROUP="plugdev"
EOF
    sudo udevadm control --reload-rules
    log_info "udev rules installed"
else
    log_info "udev rules already exist"
fi

# Add user to plugdev group
if ! groups | grep -q plugdev; then
    sudo usermod -aG plugdev "$USER"
    log_warn "Added $USER to plugdev group - log out and back in for this to take effect"
fi

echo ""
log_info "=== Prerequisites Installation Complete ==="
echo ""
echo "Installed components:"
echo "  - Git: $(git --version)"
echo "  - Python: $(python3 --version)"
echo "  - Java: $(java -version 2>&1 | head -n1)"
echo "  - ADB: $(adb version | head -n1)"
echo ""
echo "Next steps:"
echo "  1. Run ./install-android-sdk.sh to install Android SDK"
echo "  2. Set up SSH keys for Raspberry Pi access"
echo "  3. Read docs/dev-prerequisites.md for full setup guide"
echo ""

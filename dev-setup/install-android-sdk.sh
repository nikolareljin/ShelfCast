#!/usr/bin/env bash
set -euo pipefail

# ShelfCast Android SDK Setup Script
# Installs Android SDK with API 7 support for Nook Simple Touch development

echo "=== ShelfCast Android SDK Setup ==="
echo ""

# Configuration
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
CMDLINE_TOOLS_URL="https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Prefer Java 11 for Android SDK tools (sdkmanager requires 11+).
java_major() {
    local version
    version="$("$1" -version 2>&1 | head -n1 | sed -E 's/.*version "([^"]+)".*/\1/')"
    version="${version#1.}"
    echo "${version%%.*}"
}

find_java_11() {
    local candidate
    for candidate in /usr/lib/jvm/java-11-openjdk-* /usr/lib/jvm/java-11*; do
        if [[ -x "$candidate/bin/java" ]]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

if java11_home="$(find_java_11)"; then
    export JAVA_HOME="$java11_home"
    export PATH="$JAVA_HOME/bin:$PATH"
    log_info "Using JAVA_HOME=$JAVA_HOME for SDK tools."
fi

# Check Java installation
if ! command -v java &> /dev/null; then
    log_error "Java not found. Install with: sudo apt install openjdk-11-jdk"
    exit 1
fi

JAVA_VERSION=$(java -version 2>&1 | head -n1)
log_info "Found Java: $JAVA_VERSION"

# Create SDK directory
log_info "Setting up Android SDK at: $ANDROID_HOME"
mkdir -p "$ANDROID_HOME"

# Download command-line tools if not present
if [[ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]]; then
    log_info "Downloading Android command-line tools..."

    TEMP_ZIP=$(mktemp)
    wget -q --show-progress -O "$TEMP_ZIP" "$CMDLINE_TOOLS_URL"

    log_info "Extracting command-line tools..."
    unzip -q -o "$TEMP_ZIP" -d "$ANDROID_HOME"

    # Reorganize to expected structure
    mkdir -p "$ANDROID_HOME/cmdline-tools/latest"
    if [[ -d "$ANDROID_HOME/cmdline-tools/bin" ]]; then
        mv "$ANDROID_HOME/cmdline-tools"/* "$ANDROID_HOME/cmdline-tools/latest/" 2>/dev/null || true
    fi

    rm "$TEMP_ZIP"
    log_info "Command-line tools installed"
else
    log_info "Command-line tools already installed"
fi

# Set up PATH for this script
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# Accept licenses
log_info "Accepting SDK licenses..."
yes | sdkmanager --licenses > /dev/null 2>&1 || true

# Install required SDK packages
log_info "Installing SDK packages (this may take a while)..."

PACKAGES=(
    "platform-tools"
    "platforms;android-25"    # For compilation (legacy tooling)
    "platforms;android-7"     # API 7 for Nook Simple Touch
    "build-tools;25.0.3"
)

for package in "${PACKAGES[@]}"; do
    log_info "Installing: $package"
    sdkmanager "$package" > /dev/null
done

# Verify installation
log_info "Verifying installation..."
echo ""
echo "Installed packages:"
sdkmanager --list_installed 2>/dev/null | grep -E "^  " || sdkmanager --list | grep -E "Installed"

# Create environment setup script
ENV_SCRIPT="$ANDROID_HOME/env.sh"
cat > "$ENV_SCRIPT" << EOF
# Android SDK environment variables
# Source this file: source $ENV_SCRIPT

export ANDROID_HOME="$ANDROID_HOME"
export PATH="\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$PATH"
EOF

echo ""
log_info "Android SDK setup complete!"
echo ""
echo "Add to your shell profile (~/.bashrc or ~/.profile):"
echo ""
echo "  export ANDROID_HOME=\"$ANDROID_HOME\""
echo "  export PATH=\"\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$PATH\""
echo ""
echo "Or source the generated script:"
echo "  source $ENV_SCRIPT"
echo ""

# Check if already in profile
if grep -q "ANDROID_HOME" "$HOME/.bashrc" 2>/dev/null; then
    log_info "ANDROID_HOME already in ~/.bashrc"
else
    read -p "Add to ~/.bashrc now? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "" >> "$HOME/.bashrc"
        echo "# Android SDK (added by ShelfCast setup)" >> "$HOME/.bashrc"
        echo "export ANDROID_HOME=\"$ANDROID_HOME\"" >> "$HOME/.bashrc"
        echo "export PATH=\"\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$PATH\"" >> "$HOME/.bashrc"
        log_info "Added to ~/.bashrc - run 'source ~/.bashrc' or start a new terminal"
    fi
fi

# Development Prerequisites

This guide covers setting up an Ubuntu development machine for ShelfCast development.

## Overview

Development workflow:
1. **Ubuntu workstation** - Write code, build APK, test locally
2. **Raspberry Pi** - Runs the ShelfCast server (host app)
3. **Nook Simple Touch** - Connected via USB to Pi, runs the APK client

```
┌─────────────────┐     SSH      ┌─────────────────┐     USB/ADB    ┌─────────────────┐
│  Ubuntu Dev     │─────────────>│  Raspberry Pi   │<──────────────>│  Nook Simple    │
│  Machine        │              │  (Server Host)  │                │  Touch          │
│                 │              │  Port 8080      │                │  (APK Client)   │
└─────────────────┘              └─────────────────┘                └─────────────────┘
```

## Ubuntu System Requirements

- Ubuntu 20.04 LTS or newer (22.04 LTS recommended)
- 8GB RAM minimum (16GB recommended for Android builds)
- 20GB free disk space
- Network access to Raspberry Pi

## 1. Base System Packages

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential development tools
sudo apt install -y \
    git \
    curl \
    wget \
    unzip \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    openssh-client \
    rsync

# Install Java (required for Android SDK / legacy Android build)
sudo apt install -y openjdk-8-jdk openjdk-11-jdk

# Verify Java installation
java -version
```

## 2. Android SDK Setup (for Nook APK)

The Nook Simple Touch runs Android 2.1 (API Level 7). We need older SDK tools.

### Option A: Automated Setup

```bash
# Run the setup script
cd ShelfCast/dev-setup
./install-android-sdk.sh
```

### Option B: Manual Setup

```bash
# Create Android SDK directory
mkdir -p ~/Android/Sdk
export ANDROID_HOME=~/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

# Download command-line tools
cd ~/Android/Sdk
wget https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip
unzip commandlinetools-linux-9477386_latest.zip
mkdir -p cmdline-tools/latest
mv cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true

# Accept licenses
yes | sdkmanager --licenses

# Install required SDK components
sdkmanager "platform-tools"
sdkmanager "platforms;android-26"  # For compilation
sdkmanager "build-tools;26.0.2"
sdkmanager "platforms;android-7"   # Target API for Nook

# Add to shell profile
echo 'export ANDROID_HOME=~/Android/Sdk' >> ~/.bashrc
echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools' >> ~/.bashrc
source ~/.bashrc
```

## 3. Gradle Setup

```bash
# Preferred: use the Gradle wrapper included in nook-app/
cd ../nook-app
./gradlew --version

# If you must install Gradle system-wide, use a compatible version:
# Gradle 4.1 (Android Gradle Plugin 3.0.1)
```

Ensure you are using Java 8 for the Android build (AGP 3.0.1 / Gradle 4.1).

## 4. ADB Setup

```bash
# Install ADB
sudo apt install -y android-tools-adb

# Add udev rules for Nook Simple Touch
sudo tee /etc/udev/rules.d/51-android.rules << 'EOF'
# Nook Simple Touch
SUBSYSTEM=="usb", ATTR{idVendor}=="2080", MODE="0666", GROUP="plugdev"
# Generic Android
SUBSYSTEM=="usb", ATTR{idVendor}=="18d1", MODE="0666", GROUP="plugdev"
EOF

sudo udevadm control --reload-rules
sudo usermod -aG plugdev $USER
```

## 5. SSH Setup for Raspberry Pi

```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "shelfcast-dev"

# Copy key to Raspberry Pi (default user: pi)
ssh-copy-id pi@<raspberry-pi-ip>

# Create SSH config for convenience
cat >> ~/.ssh/config << 'EOF'
Host shelfcast-pi
    HostName <raspberry-pi-ip>
    User pi
    IdentityFile ~/.ssh/id_ed25519
EOF

# Test connection
ssh shelfcast-pi "echo 'SSH connection successful'"
```

## 6. Python Environment (for server testing)

```bash
# Navigate to web-app
cd ShelfCast/web-app

# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Test locally
python app.py
```

## 7. IDE Setup (Optional)

### VS Code
```bash
# Install VS Code
sudo snap install code --classic

# Install extensions
code --install-extension ms-python.python
code --install-extension redhat.java
code --install-extension vscjava.vscode-java-pack
```

### Android Studio (Alternative for APK development)
```bash
# Download and install Android Studio
sudo snap install android-studio --classic
```

## Environment Variables Summary

Add to `~/.bashrc` or `~/.profile`:

```bash
# Android SDK
export ANDROID_HOME=~/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Java
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

# ShelfCast
export SHELFCAST_PI_HOST=shelfcast-pi
export SHELFCAST_PI_USER=pi
export SHELFCAST_PI_PATH=/home/pi/ShelfCast
```

## Verification Checklist

Run these commands to verify your setup:

```bash
# Check Java
java -version          # Should show OpenJDK 11

# Check Android SDK
adb version            # Should show ADB version
sdkmanager --list      # Should list installed packages

# Check Gradle
gradle --version       # Should show Gradle 7.x

# Check Python
python3 --version      # Should show Python 3.8+

# Check SSH to Pi
ssh shelfcast-pi "hostname"  # Should print Pi hostname

# Check Git
git --version          # Should show git version
```

## Next Steps

1. **Build the Nook APK**: See `nook-app/README.md`
2. **Deploy to Pi**: See `docs/deployment.md`
3. **Test locally**: See `docs/07-ubuntu-test.md`

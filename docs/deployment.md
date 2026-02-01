# Deployment Guide

Deploy ShelfCast from Ubuntu development machine to Raspberry Pi via SSH.

## Architecture

```
Ubuntu Dev Machine                    Raspberry Pi                      Nook Simple Touch
┌────────────────────┐               ┌────────────────────┐            ┌─────────────────┐
│  Source Code       │               │  ShelfCast Server  │            │  ShelfCast APK  │
│  - web-app/        │    SSH/SCP    │  - Flask app       │   USB/ADB  │  - WebView      │
│  - nook-app/       │ ────────────> │  - Port 8080       │ <────────> │  - Kiosk mode   │
│  - scripts/        │               │  - systemd service │            │                 │
│                    │               │                    │            │                 │
│  Build APK locally │               │  Receives APK      │            │  Installed via  │
│  Deploy via SSH    │               │  Installs to Nook  │            │  adb install    │
└────────────────────┘               └────────────────────┘            └─────────────────┘
```

## Prerequisites

1. SSH access to Raspberry Pi configured (see `docs/dev-prerequisites.md`)
2. Raspberry Pi on same network or accessible via SSH
3. Development environment set up on Ubuntu

## Quick Deploy

### Deploy Server (Web App)

```bash
# From Ubuntu development machine
./scripts/deploy-to-pi.sh

# Or with custom Pi address
PI_HOST=192.168.1.100 ./scripts/deploy-to-pi.sh
```

### Deploy Nook APK

```bash
# Build APK on Ubuntu
cd nook-app
./gradlew assembleRelease

# Deploy APK to Pi, then install on Nook
./scripts/deploy-apk-to-pi.sh
```

## Manual Deployment Steps

### 1. Deploy Server Code

```bash
# Set variables
PI_HOST="shelfcast-pi"  # or IP address
PI_USER="pi"
PI_PATH="/home/pi/ShelfCast"

# Sync code (excludes build artifacts)
rsync -avz --delete \
    --exclude '.git' \
    --exclude '.venv' \
    --exclude '__pycache__' \
    --exclude 'nook-app/app/build' \
    --exclude '*.pyc' \
    ./ ${PI_USER}@${PI_HOST}:${PI_PATH}/

# Install/update on Pi
ssh ${PI_USER}@${PI_HOST} "cd ${PI_PATH} && ./scripts/run-web.sh"
```

### 2. Build and Deploy APK

```bash
# Build on Ubuntu
cd nook-app
./gradlew assembleRelease

# Copy APK to Pi
APK_PATH="app/build/outputs/apk/release/app-release.apk"
scp "$APK_PATH" ${PI_USER}@${PI_HOST}:/home/pi/shelfcast-nook.apk

# Install on Nook (from Pi, with Nook connected via USB)
ssh ${PI_USER}@${PI_HOST} << 'EOF'
adb devices
adb install -r /home/pi/shelfcast-nook.apk
adb reverse tcp:8080 tcp:8080
adb shell am start -n com.shelfcast.nook/.MainActivity
EOF
```

### 3. Set Up systemd Service

```bash
# Copy and enable service on Pi
ssh ${PI_USER}@${PI_HOST} << 'EOF'
sudo cp /home/pi/ShelfCast/raspberry-pi/shelfcast.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable shelfcast
sudo systemctl start shelfcast
sudo systemctl status shelfcast
EOF
```

## Deployment Scripts

### deploy-to-pi.sh

Full server deployment:
- Syncs code via rsync
- Installs Python dependencies
- Restarts the service

### deploy-apk-to-pi.sh

APK deployment:
- Builds APK locally (if needed)
- Copies to Pi
- Installs on Nook via ADB

### pi-shell.sh

Quick SSH access to Pi for manual operations.

## Configuration

### Environment Variables

Set these in your shell or a `.env.local` file:

```bash
# Raspberry Pi connection
export SHELFCAST_PI_HOST="192.168.1.100"  # or hostname
export SHELFCAST_PI_USER="pi"
export SHELFCAST_PI_PATH="/home/pi/ShelfCast"

# SSH key (optional, uses default if not set)
export SHELFCAST_SSH_KEY="~/.ssh/id_ed25519"
```

### SSH Config

For convenience, add to `~/.ssh/config`:

```
Host shelfcast-pi
    HostName 192.168.1.100
    User pi
    IdentityFile ~/.ssh/id_ed25519
```

Then use: `ssh shelfcast-pi`

## Troubleshooting

### SSH Connection Issues

```bash
# Test connection
ssh -v shelfcast-pi

# If key not accepted, copy again
ssh-copy-id pi@<pi-ip>
```

### ADB Not Finding Nook

```bash
# On Pi, check USB connection
lsusb | grep -i nook

# Restart ADB
adb kill-server
adb start-server
adb devices
```

### Service Not Starting

```bash
# Check logs on Pi
sudo journalctl -u shelfcast -f

# Check if port in use
sudo netstat -tlnp | grep 8080
```

### APK Installation Fails

```bash
# Check Nook connection
adb devices

# Enable USB debugging on Nook
# Settings > Developer Options > USB Debugging

# Clear existing app
adb uninstall com.shelfcast.nook
adb install /path/to/shelfcast-nook.apk
```

## Continuous Development Workflow

1. **Edit code** on Ubuntu
2. **Test locally**: `cd ubuntu-test && ./run.sh`
3. **Deploy to Pi**: `./scripts/deploy-to-pi.sh`
4. **View on Nook**: App auto-refreshes or press menu button

For rapid iteration, use the watch mode:

```bash
# Watch for changes and auto-deploy
./scripts/watch-deploy.sh
```

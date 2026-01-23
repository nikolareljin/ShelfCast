# Nook Simple Touch Setup

The Nook Simple Touch runs Android 2.1 (Eclair), connected to Raspberry Pi via USB for ADB control.

## Architecture

```
┌──────────────────┐         USB Cable          ┌──────────────────┐
│  Raspberry Pi    │◄──────────────────────────►│  Nook Simple     │
│                  │                            │  Touch           │
│  - ShelfCast     │         ADB Commands       │                  │
│    Server :8080  │ ──────────────────────────►│  - ShelfCast APK │
│  - ADB Host      │                            │  - WebView       │
│  - nook-ctl.sh   │◄────────────────────────── │  - USB Debugging │
│                  │         Port Forward       │                  │
└──────────────────┘    (localhost:8080)        └──────────────────┘
```

## Prerequisites

### Root the Nook (Required)

The Nook must be rooted to enable USB debugging. Options:

1. **NookManager** (recommended): Boot from microSD, select root option
2. **Manual**: Flash custom recovery and root package

Resources:
- XDA Developers Nook Simple Touch forum
- NookDevs wiki

### Enable USB Debugging on Nook

1. Install a Settings app (NookManager includes one, or sideload `Settings.apk`)
2. Navigate to: Settings > Applications > Development
3. Enable: **USB debugging**
4. Connect USB cable to Raspberry Pi

## Raspberry Pi Setup

### Install ADB Tools

```bash
# Run the setup script
cd /home/pi/ShelfCast/raspberry-pi/adb
./setup-adb.sh

# Or manually:
sudo apt install -y android-tools-adb
sudo cp 51-nook.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

### Verify Connection

```bash
# Check if Nook is detected
nook-ctl status

# Expected output:
# Status: Connected
# Model: NOOK BNRV300
# Android: 2.1
```

## Controlling the Nook

### Quick Start

```bash
# Open ShelfCast dashboard
nook-ctl dashboard

# Force e-ink refresh
nook-ctl refresh

# Take screenshot
nook-ctl screenshot

# Open any URL
nook-ctl url "http://example.com"
```

### Full Command Reference

See `raspberry-pi/adb/README.md` for complete command list, or run:

```bash
nook-ctl help
```

### Common Operations

```bash
# Display management
nook-ctl dashboard          # Show ShelfCast
nook-ctl refresh            # Refresh e-ink
nook-ctl brightness 50      # Set 50% brightness

# Input simulation
nook-ctl tap 300 400        # Tap at coordinates
nook-ctl key menu           # Press menu button
nook-ctl key back           # Press back button

# App management
nook-ctl install app.apk    # Install APK
nook-ctl launch             # Launch ShelfCast
nook-ctl list               # List installed apps

# File operations
nook-ctl push file.html /sdcard/
nook-ctl pull /sdcard/file.txt ./

# System
nook-ctl info               # Device information
nook-ctl shell              # Interactive shell
nook-ctl reboot             # Reboot Nook
```

## Auto-Start Monitor

Enable automatic dashboard launch when Nook connects:

```bash
# Install the monitor service
sudo cp raspberry-pi/adb/nook-monitor.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable nook-monitor
sudo systemctl start nook-monitor

# Check status
sudo systemctl status nook-monitor
```

The monitor:
- Detects when Nook is connected via USB
- Automatically sets up port forwarding
- Launches ShelfCast dashboard
- Periodically refreshes the e-ink display

## Port Forwarding

The Nook accesses ShelfCast via ADB reverse port forwarding:

```bash
# Set up (done automatically by nook-ctl dashboard)
adb reverse tcp:8080 tcp:8080
```

This makes `http://localhost:8080` on the Nook route to the Pi's ShelfCast server.

## E-ink Display Tips

- **Refresh regularly**: E-ink displays accumulate ghosting; use `nook-ctl refresh`
- **High contrast**: The dashboard uses dark text on light background for best readability
- **No animations**: Animations don't work well on e-ink; the dashboard avoids them
- **Page changes**: Use `nook-ctl key page_down` for page navigation

## Troubleshooting

### "device not found"

```bash
# Check USB connection
lsusb | grep -i "2080"  # Nook vendor ID

# Restart ADB
adb kill-server
adb start-server
adb devices

# Check permissions
ls -la /dev/bus/usb/*/*
```

### "unauthorized"

1. Check Nook screen for USB debugging authorization prompt
2. Accept the connection on Nook
3. If no prompt, USB debugging may not be enabled

### Connection Drops

- Use a quality data USB cable (not charge-only)
- Try different USB port on Pi
- Check Pi power supply (use official adapter)
- Avoid USB hubs

### App Won't Launch

```bash
# Check if app is installed
adb shell pm list packages | grep shelfcast

# Reinstall
nook-ctl install /home/pi/shelfcast-nook.apk

# Check logcat for errors
nook-ctl log ShelfCast
```

## Display Control Scripts

Additional display utilities are available:

```bash
cd raspberry-pi/adb

# High-level display control
./display.sh dashboard       # Show ShelfCast
./display.sh url "http://..."  # Display URL
./display.sh message "Title" "Body text"  # Show message
./display.sh image photo.png  # Display image
./display.sh refresh         # Full e-ink refresh
./display.sh scroll down     # Scroll page
```

## Android Tablet/Phone Alternative

For Android 4+ devices instead of Nook:

1. Connect to same WiFi as Pi
2. Open browser: `http://<pi-ip>:8080`
3. Enable kiosk/pinned mode if available
4. Optional: USB connection with `./scripts/android-provision.sh`

### Tips for Older Android

- Use lightweight browser (stock or Firefox)
- Enable "Stay awake while charging"
- Create home screen shortcut to dashboard
- Use kiosk app to lock to dashboard

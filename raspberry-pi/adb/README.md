# ADB Control for Nook Simple Touch

Control, manage, and display content on the Nook Simple Touch from Raspberry Pi via USB/ADB.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      Raspberry Pi                                │
│  ┌─────────────┐    ┌──────────────┐    ┌───────────────────┐   │
│  │ ShelfCast   │    │  ADB Server  │    │  nook-ctl.sh      │   │
│  │ Web Server  │    │  (adb daemon)│    │  (control scripts)│   │
│  │ :8080       │    │              │    │                   │   │
│  └──────┬──────┘    └──────┬───────┘    └─────────┬─────────┘   │
│         │                  │                      │             │
│         └──────────────────┼──────────────────────┘             │
│                            │                                     │
│                       USB Cable                                  │
│                            │                                     │
└────────────────────────────┼────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Nook Simple Touch                             │
│  ┌─────────────┐    ┌──────────────┐    ┌───────────────────┐   │
│  │ ShelfCast   │    │  ADB Daemon  │    │  Android System   │   │
│  │ App (APK)   │◄───│  (adbd)      │◄───│  Services         │   │
│  │ WebView     │    │  USB Debug   │    │                   │   │
│  └─────────────┘    └──────────────┘    └───────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### On Raspberry Pi

```bash
# Install ADB
sudo apt update
sudo apt install -y android-tools-adb

# Add user to plugdev group
sudo usermod -aG plugdev $USER

# Install udev rules for Nook
sudo cp /home/pi/ShelfCast/raspberry-pi/adb/51-nook.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
```

### On Nook Simple Touch

1. **Root the Nook** (required for ADB):
   - The Nook Simple Touch needs to be rooted to enable ADB
   - Use NookManager or similar tool to root

2. **Enable USB Debugging**:
   - Install a settings app (e.g., "Settings.apk" from NookManager)
   - Go to Settings > Applications > Development
   - Enable "USB debugging"

3. **Connect via USB**:
   - Use a micro-USB cable
   - Connect Nook to Pi's USB port

## Quick Start

```bash
# Check if Nook is connected
./nook-ctl.sh status

# Open ShelfCast dashboard on Nook
./nook-ctl.sh dashboard

# Refresh the e-ink display
./nook-ctl.sh refresh

# Install/update ShelfCast app
./nook-ctl.sh install /path/to/shelfcast-nook.apk
```

## Available Commands

| Command | Description |
|---------|-------------|
| `status` | Check Nook connection status |
| `dashboard` | Open ShelfCast dashboard URL |
| `refresh` | Force e-ink display refresh |
| `install <apk>` | Install an APK on Nook |
| `uninstall <pkg>` | Uninstall an app |
| `launch` | Launch ShelfCast app |
| `screenshot` | Capture screenshot from Nook |
| `shell` | Open interactive ADB shell |
| `reboot` | Reboot the Nook |
| `push <src> <dst>` | Copy file to Nook |
| `pull <src> <dst>` | Copy file from Nook |
| `brightness <0-100>` | Set screen brightness |
| `url <url>` | Open URL in browser |
| `input <text>` | Send text input |
| `tap <x> <y>` | Simulate screen tap |
| `key <keycode>` | Send key event |
| `info` | Show device information |
| `log` | Show Android logcat |

## Port Forwarding

The Nook accesses ShelfCast via ADB reverse port forwarding:

```bash
# Set up reverse forwarding (Nook localhost:8080 -> Pi localhost:8080)
adb reverse tcp:8080 tcp:8080

# Verify
adb reverse --list
```

This is automatically set up by `nook-ctl.sh dashboard`.

## Troubleshooting

### "device not found"
- Check USB cable is connected
- Verify USB debugging is enabled on Nook
- Try: `adb kill-server && adb start-server`
- Check: `lsusb | grep -i nook`

### "unauthorized"
- Accept the USB debugging prompt on Nook
- If no prompt appears, Nook may need to be re-rooted

### Connection drops
- Use a quality USB cable (data cable, not charge-only)
- Try a different USB port on the Pi
- Check Pi power supply is adequate

## Files

- `nook-ctl.sh` - Main control script
- `setup-adb.sh` - One-time ADB setup on Pi
- `51-nook.rules` - udev rules for Nook USB
- `monitor.sh` - Auto-reconnect monitor daemon

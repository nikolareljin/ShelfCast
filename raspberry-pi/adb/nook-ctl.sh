#!/usr/bin/env bash
set -euo pipefail

# nook-ctl.sh - Control Nook Simple Touch from Raspberry Pi via ADB
# Usage: ./nook-ctl.sh <command> [args...]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELFCAST_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
SHELFCAST_PORT="${SHELFCAST_PORT:-8080}"
SHELFCAST_PACKAGE="com.shelfcast.nook"
SHELFCAST_ACTIVITY="com.shelfcast.nook/.MainActivity"
SCREENSHOT_DIR="${SCREENSHOT_DIR:-/home/pi/screenshots}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_cmd() { echo -e "${CYAN}[CMD]${NC} $*"; }

# Check ADB is installed
check_adb() {
    if ! command -v adb &> /dev/null; then
        log_error "ADB not installed. Run: sudo apt install android-tools-adb"
        exit 1
    fi
}

# Ensure ADB server is running
ensure_adb_server() {
    adb start-server > /dev/null 2>&1
}

# Check if Nook is connected
check_device() {
    local devices
    devices=$(adb devices 2>/dev/null | grep -v "List" | grep -v "^$" | grep -c "device$" || echo "0")
    if [[ "$devices" -eq 0 ]]; then
        return 1
    fi
    return 0
}

# Wait for device with timeout
wait_for_device() {
    local timeout="${1:-30}"
    local elapsed=0

    log_info "Waiting for Nook connection (${timeout}s timeout)..."

    while [[ $elapsed -lt $timeout ]]; do
        if check_device; then
            log_info "Nook connected!"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
        echo -ne "\r  Waiting... ${elapsed}s"
    done
    echo ""
    log_error "Timeout: No device found after ${timeout}s"
    return 1
}

# Get device serial
get_device_serial() {
    adb devices 2>/dev/null | grep "device$" | head -n1 | cut -f1
}

# Show usage
show_usage() {
    cat << 'EOF'
nook-ctl.sh - Control Nook Simple Touch via ADB

USAGE:
    ./nook-ctl.sh <command> [arguments]

CONNECTION COMMANDS:
    status              Check Nook connection status
    wait [timeout]      Wait for Nook to connect (default: 30s)
    info                Show device information
    shell               Open interactive ADB shell

SHELFCAST COMMANDS:
    dashboard           Open ShelfCast dashboard (sets up port forwarding)
    launch              Launch ShelfCast app
    refresh             Force e-ink display refresh
    reload              Reload current page in app

DISPLAY COMMANDS:
    url <url>           Open URL in browser
    brightness <0-100>  Set screen brightness (0=off, 100=max)
    screenshot [file]   Capture screenshot
    clear               Clear/refresh e-ink display

APP MANAGEMENT:
    install <apk>       Install APK on Nook
    uninstall [pkg]     Uninstall app (default: ShelfCast)
    list                List installed packages
    start <activity>    Start an activity

INPUT COMMANDS:
    tap <x> <y>         Simulate screen tap at coordinates
    swipe <x1> <y1> <x2> <y2>  Simulate swipe gesture
    key <keycode>       Send key event (home, back, menu, etc.)
    input <text>        Send text input

FILE OPERATIONS:
    push <src> <dst>    Copy file from Pi to Nook
    pull <src> [dst]    Copy file from Nook to Pi

SYSTEM COMMANDS:
    reboot              Reboot the Nook
    log [filter]        Show Android logcat
    forward             Set up ADB port forwarding

EXAMPLES:
    ./nook-ctl.sh dashboard          # Start ShelfCast on Nook
    ./nook-ctl.sh screenshot         # Take screenshot
    ./nook-ctl.sh url "http://example.com"
    ./nook-ctl.sh tap 400 300        # Tap center of screen
    ./nook-ctl.sh key home           # Press home button
    ./nook-ctl.sh brightness 50      # Set 50% brightness

EOF
}

# === COMMAND IMPLEMENTATIONS ===

cmd_status() {
    check_adb
    ensure_adb_server

    echo "=== Nook Connection Status ==="
    echo ""

    if check_device; then
        local serial
        serial=$(get_device_serial)
        echo -e "Status: ${GREEN}Connected${NC}"
        echo "Serial: $serial"

        # Get device info
        local model brand android_version
        model=$(adb shell getprop ro.product.model 2>/dev/null | tr -d '\r' || echo "unknown")
        brand=$(adb shell getprop ro.product.brand 2>/dev/null | tr -d '\r' || echo "unknown")
        android_version=$(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\r' || echo "unknown")

        echo "Model: $brand $model"
        echo "Android: $android_version"

        # Check port forwarding
        echo ""
        echo "Port forwarding:"
        adb reverse --list 2>/dev/null || echo "  (none)"
    else
        echo -e "Status: ${RED}Not connected${NC}"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Connect Nook via USB cable"
        echo "  2. Enable USB debugging on Nook"
        echo "  3. Run: adb kill-server && adb start-server"
    fi
}

cmd_wait() {
    check_adb
    ensure_adb_server
    local timeout="${1:-30}"
    wait_for_device "$timeout"
}

cmd_info() {
    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    echo "=== Nook Device Information ==="
    echo ""
    echo "Model:      $(adb shell getprop ro.product.model | tr -d '\r')"
    echo "Brand:      $(adb shell getprop ro.product.brand | tr -d '\r')"
    echo "Device:     $(adb shell getprop ro.product.device | tr -d '\r')"
    echo "Android:    $(adb shell getprop ro.build.version.release | tr -d '\r')"
    echo "SDK:        $(adb shell getprop ro.build.version.sdk | tr -d '\r')"
    echo "Build:      $(adb shell getprop ro.build.display.id | tr -d '\r')"
    echo "Serial:     $(adb shell getprop ro.serialno | tr -d '\r')"
    echo ""
    echo "Screen:"
    local screen_info
    screen_info=$(adb shell dumpsys window 2>/dev/null | grep -E "mCurrentFocus|DisplayWidth|DisplayHeight" | head -3 || echo "  (not available)")
    echo "$screen_info"
    echo ""
    echo "Battery:"
    adb shell dumpsys battery 2>/dev/null | grep -E "level|status|powered" | head -5 || echo "  (not available)"
}

cmd_dashboard() {
    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    log_info "Setting up ShelfCast dashboard..."

    # Set up reverse port forwarding
    log_cmd "Setting up port forwarding (Nook:$SHELFCAST_PORT -> Pi:$SHELFCAST_PORT)"
    adb reverse tcp:$SHELFCAST_PORT tcp:$SHELFCAST_PORT

    # Check if ShelfCast app is installed
    if adb shell pm list packages 2>/dev/null | grep -q "$SHELFCAST_PACKAGE"; then
        log_info "Launching ShelfCast app..."
        adb shell am start -n "$SHELFCAST_ACTIVITY" 2>/dev/null || {
            log_warn "Could not launch app, opening URL in browser instead"
            adb shell am start -a android.intent.action.VIEW -d "http://localhost:$SHELFCAST_PORT" 2>/dev/null
        }
    else
        log_warn "ShelfCast app not installed, opening in browser..."
        adb shell am start -a android.intent.action.VIEW -d "http://localhost:$SHELFCAST_PORT" 2>/dev/null || true
    fi

    log_info "Dashboard should now be visible on Nook"
    echo ""
    echo "Nook is connected to: http://localhost:$SHELFCAST_PORT"
    echo "  (which routes to Pi's ShelfCast server)"
}

cmd_launch() {
    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    log_info "Launching ShelfCast app..."
    adb shell am start -n "$SHELFCAST_ACTIVITY"
}

cmd_refresh() {
    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    log_info "Forcing e-ink display refresh..."

    # Method 1: Send refresh intent (if supported)
    adb shell am broadcast -a android.intent.action.SCREEN_ON 2>/dev/null || true

    # Method 2: Toggle screen state
    adb shell input keyevent KEYCODE_WAKEUP 2>/dev/null || true

    # Method 3: Simulate a tap to trigger refresh
    adb shell input tap 1 1 2>/dev/null || true

    log_info "Refresh signal sent"
}

cmd_reload() {
    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    log_info "Reloading ShelfCast page..."

    # Send menu key to trigger refresh in the app
    adb shell input keyevent KEYCODE_MENU

    log_info "Reload triggered"
}

cmd_url() {
    local url="${1:-}"

    if [[ -z "$url" ]]; then
        log_error "Usage: ./nook-ctl.sh url <url>"
        exit 1
    fi

    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    log_info "Opening URL: $url"
    adb shell am start -a android.intent.action.VIEW -d "$url"
}

cmd_brightness() {
    local level="${1:-}"

    if [[ -z "$level" ]] || ! [[ "$level" =~ ^[0-9]+$ ]] || [[ "$level" -gt 100 ]]; then
        log_error "Usage: ./nook-ctl.sh brightness <0-100>"
        exit 1
    fi

    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    # Convert 0-100 to 0-255
    local value=$((level * 255 / 100))

    log_info "Setting brightness to $level% (value: $value)"
    adb shell settings put system screen_brightness "$value" 2>/dev/null || {
        # Fallback for older Android
        adb shell "echo $value > /sys/class/backlight/*/brightness" 2>/dev/null || true
    }
}

cmd_screenshot() {
    local output="${1:-}"

    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    mkdir -p "$SCREENSHOT_DIR"

    if [[ -z "$output" ]]; then
        output="$SCREENSHOT_DIR/nook_$(date +%Y%m%d_%H%M%S).png"
    fi

    log_info "Capturing screenshot..."

    # Capture on device
    adb shell screencap /sdcard/screenshot.png 2>/dev/null || {
        log_error "Screenshot capture failed (screencap not available)"
        exit 1
    }

    # Pull to Pi
    adb pull /sdcard/screenshot.png "$output" 2>/dev/null

    # Clean up on device
    adb shell rm /sdcard/screenshot.png 2>/dev/null || true

    log_info "Screenshot saved: $output"
}

cmd_clear() {
    cmd_refresh
}

cmd_install() {
    local apk="${1:-}"

    if [[ -z "$apk" ]]; then
        log_error "Usage: ./nook-ctl.sh install <apk-file>"
        exit 1
    fi

    if [[ ! -f "$apk" ]]; then
        log_error "APK file not found: $apk"
        exit 1
    fi

    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    log_info "Installing: $(basename "$apk")"
    adb install -r "$apk"
    log_info "Installation complete"
}

cmd_uninstall() {
    local package="${1:-$SHELFCAST_PACKAGE}"

    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    log_info "Uninstalling: $package"
    adb uninstall "$package"
}

cmd_list() {
    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    echo "=== Installed Packages ==="
    adb shell pm list packages | sed 's/package://' | sort
}

cmd_start() {
    local activity="${1:-}"

    if [[ -z "$activity" ]]; then
        log_error "Usage: ./nook-ctl.sh start <package/activity>"
        exit 1
    fi

    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    log_info "Starting: $activity"
    adb shell am start -n "$activity"
}

cmd_tap() {
    local x="${1:-}"
    local y="${2:-}"

    if [[ -z "$x" ]] || [[ -z "$y" ]]; then
        log_error "Usage: ./nook-ctl.sh tap <x> <y>"
        echo "  Nook screen: 600x800 (portrait)"
        exit 1
    fi

    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    log_cmd "Tap at ($x, $y)"
    adb shell input tap "$x" "$y"
}

cmd_swipe() {
    local x1="${1:-}"
    local y1="${2:-}"
    local x2="${3:-}"
    local y2="${4:-}"
    local duration="${5:-300}"

    if [[ -z "$x1" ]] || [[ -z "$y1" ]] || [[ -z "$x2" ]] || [[ -z "$y2" ]]; then
        log_error "Usage: ./nook-ctl.sh swipe <x1> <y1> <x2> <y2> [duration_ms]"
        exit 1
    fi

    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    log_cmd "Swipe ($x1,$y1) -> ($x2,$y2)"
    adb shell input swipe "$x1" "$y1" "$x2" "$y2" "$duration"
}

cmd_key() {
    local key="${1:-}"

    if [[ -z "$key" ]]; then
        log_error "Usage: ./nook-ctl.sh key <keycode>"
        echo ""
        echo "Common keycodes:"
        echo "  home, back, menu, power, enter"
        echo "  volume_up, volume_down"
        echo "  dpad_up, dpad_down, dpad_left, dpad_right, dpad_center"
        echo "  page_up, page_down"
        exit 1
    fi

    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    # Map friendly names to keycodes
    local keycode
    case "${key,,}" in
        home)        keycode="KEYCODE_HOME" ;;
        back)        keycode="KEYCODE_BACK" ;;
        menu)        keycode="KEYCODE_MENU" ;;
        power)       keycode="KEYCODE_POWER" ;;
        enter)       keycode="KEYCODE_ENTER" ;;
        volume_up)   keycode="KEYCODE_VOLUME_UP" ;;
        volume_down) keycode="KEYCODE_VOLUME_DOWN" ;;
        dpad_up)     keycode="KEYCODE_DPAD_UP" ;;
        dpad_down)   keycode="KEYCODE_DPAD_DOWN" ;;
        dpad_left)   keycode="KEYCODE_DPAD_LEFT" ;;
        dpad_right)  keycode="KEYCODE_DPAD_RIGHT" ;;
        dpad_center) keycode="KEYCODE_DPAD_CENTER" ;;
        page_up)     keycode="KEYCODE_PAGE_UP" ;;
        page_down)   keycode="KEYCODE_PAGE_DOWN" ;;
        *)           keycode="$key" ;;
    esac

    log_cmd "Key: $keycode"
    adb shell input keyevent "$keycode"
}

cmd_input() {
    local text="${1:-}"

    if [[ -z "$text" ]]; then
        log_error "Usage: ./nook-ctl.sh input <text>"
        exit 1
    fi

    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    # Escape special characters for shell
    text="${text// /%s}"

    log_cmd "Input text"
    adb shell input text "$text"
}

cmd_push() {
    local src="${1:-}"
    local dst="${2:-}"

    if [[ -z "$src" ]] || [[ -z "$dst" ]]; then
        log_error "Usage: ./nook-ctl.sh push <local-file> <remote-path>"
        exit 1
    fi

    if [[ ! -f "$src" ]]; then
        log_error "Source file not found: $src"
        exit 1
    fi

    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    log_info "Pushing: $src -> $dst"
    adb push "$src" "$dst"
}

cmd_pull() {
    local src="${1:-}"
    local dst="${2:-.}"

    if [[ -z "$src" ]]; then
        log_error "Usage: ./nook-ctl.sh pull <remote-path> [local-path]"
        exit 1
    fi

    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    log_info "Pulling: $src -> $dst"
    adb pull "$src" "$dst"
}

cmd_reboot() {
    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    log_warn "Rebooting Nook..."
    adb reboot
    log_info "Reboot command sent"
}

cmd_log() {
    local filter="${1:-}"

    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    log_info "Showing logcat (Ctrl+C to stop)..."

    if [[ -n "$filter" ]]; then
        adb logcat -s "$filter"
    else
        adb logcat
    fi
}

cmd_shell() {
    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    log_info "Opening ADB shell (type 'exit' to quit)..."
    adb shell
}

cmd_forward() {
    check_adb
    ensure_adb_server

    if ! check_device; then
        log_error "No device connected"
        exit 1
    fi

    log_info "Setting up port forwarding..."

    # Reverse: Nook can reach Pi's server
    adb reverse tcp:$SHELFCAST_PORT tcp:$SHELFCAST_PORT
    log_info "Reverse: Nook localhost:$SHELFCAST_PORT -> Pi localhost:$SHELFCAST_PORT"

    echo ""
    echo "Current forwarding:"
    adb reverse --list 2>/dev/null || echo "  (none)"
}

# === MAIN ===

main() {
    local command="${1:-}"

    if [[ -z "$command" ]] || [[ "$command" == "help" ]] || [[ "$command" == "--help" ]] || [[ "$command" == "-h" ]]; then
        show_usage
        exit 0
    fi

    shift

    case "$command" in
        status)      cmd_status ;;
        wait)        cmd_wait "$@" ;;
        info)        cmd_info ;;
        dashboard)   cmd_dashboard ;;
        launch)      cmd_launch ;;
        refresh)     cmd_refresh ;;
        reload)      cmd_reload ;;
        url)         cmd_url "$@" ;;
        brightness)  cmd_brightness "$@" ;;
        screenshot)  cmd_screenshot "$@" ;;
        clear)       cmd_clear ;;
        install)     cmd_install "$@" ;;
        uninstall)   cmd_uninstall "$@" ;;
        list)        cmd_list ;;
        start)       cmd_start "$@" ;;
        tap)         cmd_tap "$@" ;;
        swipe)       cmd_swipe "$@" ;;
        key)         cmd_key "$@" ;;
        input)       cmd_input "$@" ;;
        push)        cmd_push "$@" ;;
        pull)        cmd_pull "$@" ;;
        reboot)      cmd_reboot ;;
        log)         cmd_log "$@" ;;
        shell)       cmd_shell ;;
        forward)     cmd_forward ;;
        *)
            log_error "Unknown command: $command"
            echo "Run './nook-ctl.sh help' for usage"
            exit 1
            ;;
    esac
}

main "$@"

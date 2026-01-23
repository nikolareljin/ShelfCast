#!/usr/bin/env bash
set -euo pipefail

# display.sh - High-level display control for Nook Simple Touch
# Optimized functions for e-ink display management

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Nook Simple Touch display specs
SCREEN_WIDTH=600
SCREEN_HEIGHT=800

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Check ADB connection
check_connection() {
    if ! adb devices 2>/dev/null | grep -q "device$"; then
        echo "Error: Nook not connected"
        exit 1
    fi
}

# Force full e-ink refresh (clears ghosting)
full_refresh() {
    check_connection
    log_info "Performing full e-ink refresh..."

    # Method 1: Toggle screen off/on
    adb shell input keyevent KEYCODE_POWER 2>/dev/null || true
    sleep 0.5
    adb shell input keyevent KEYCODE_POWER 2>/dev/null || true
    sleep 0.5

    # Method 2: Broadcast screen on
    adb shell am broadcast -a android.intent.action.SCREEN_ON 2>/dev/null || true

    log_info "Refresh complete"
}

# Display a URL in fullscreen
show_url() {
    local url="$1"
    check_connection

    log_info "Displaying URL: $url"

    # Ensure port forwarding if localhost
    if [[ "$url" == *"localhost"* ]] || [[ "$url" == *"127.0.0.1"* ]]; then
        adb reverse tcp:8080 tcp:8080 2>/dev/null || true
    fi

    # Open URL
    adb shell am start -a android.intent.action.VIEW -d "$url"

    # Wait and refresh for e-ink
    sleep 2
    full_refresh
}

# Display ShelfCast dashboard
show_dashboard() {
    check_connection
    log_info "Showing ShelfCast dashboard..."

    # Set up port forwarding
    adb reverse tcp:8080 tcp:8080

    # Launch ShelfCast app or browser
    if adb shell pm list packages 2>/dev/null | grep -q "com.shelfcast.nook"; then
        adb shell am start -n com.shelfcast.nook/.MainActivity
    else
        adb shell am start -a android.intent.action.VIEW -d "http://localhost:8080"
    fi

    sleep 2
    full_refresh
}

# Show a local HTML file
show_html() {
    local html_file="$1"
    check_connection

    if [[ ! -f "$html_file" ]]; then
        echo "Error: File not found: $html_file"
        exit 1
    fi

    log_info "Pushing HTML file to Nook..."
    adb push "$html_file" /sdcard/display.html

    log_info "Opening in browser..."
    adb shell am start -a android.intent.action.VIEW -d "file:///sdcard/display.html"

    sleep 2
    full_refresh
}

# Display a message (creates simple HTML)
show_message() {
    local title="${1:-}"
    local body="${2:-}"
    local font_size="${3:-48}"

    check_connection

    log_info "Displaying message..."

    # Create temporary HTML
    local html="<html><head><meta charset='utf-8'><style>
body { font-family: serif; background: #fff; color: #000; margin: 40px; }
h1 { font-size: ${font_size}px; margin-bottom: 20px; }
p { font-size: $((font_size / 2))px; line-height: 1.5; }
</style></head><body>
<h1>${title}</h1>
<p>${body}</p>
</body></html>"

    echo "$html" > /tmp/nook_message.html
    adb push /tmp/nook_message.html /sdcard/message.html
    adb shell am start -a android.intent.action.VIEW -d "file:///sdcard/message.html"

    sleep 2
    full_refresh
    rm /tmp/nook_message.html
}

# Display an image
show_image() {
    local image_file="$1"
    check_connection

    if [[ ! -f "$image_file" ]]; then
        echo "Error: Image not found: $image_file"
        exit 1
    fi

    log_info "Pushing image to Nook..."
    adb push "$image_file" /sdcard/display_image.png

    log_info "Opening image..."
    adb shell am start -a android.intent.action.VIEW -t image/* -d "file:///sdcard/display_image.png"

    sleep 2
    full_refresh
}

# Navigate within current app
navigate() {
    local direction="$1"
    check_connection

    case "$direction" in
        up)      adb shell input keyevent KEYCODE_DPAD_UP ;;
        down)    adb shell input keyevent KEYCODE_DPAD_DOWN ;;
        left)    adb shell input keyevent KEYCODE_DPAD_LEFT ;;
        right)   adb shell input keyevent KEYCODE_DPAD_RIGHT ;;
        select)  adb shell input keyevent KEYCODE_DPAD_CENTER ;;
        back)    adb shell input keyevent KEYCODE_BACK ;;
        home)    adb shell input keyevent KEYCODE_HOME ;;
        *)       echo "Unknown direction: $direction" ;;
    esac
}

# Scroll the page
scroll() {
    local direction="${1:-down}"
    check_connection

    case "$direction" in
        up)
            adb shell input swipe $((SCREEN_WIDTH/2)) $((SCREEN_HEIGHT/4)) $((SCREEN_WIDTH/2)) $((SCREEN_HEIGHT*3/4)) 300
            ;;
        down)
            adb shell input swipe $((SCREEN_WIDTH/2)) $((SCREEN_HEIGHT*3/4)) $((SCREEN_WIDTH/2)) $((SCREEN_HEIGHT/4)) 300
            ;;
        *)
            echo "Usage: scroll [up|down]"
            ;;
    esac

    sleep 0.5
    full_refresh
}

# Go to sleep / wake up
sleep_display() {
    check_connection
    log_info "Putting display to sleep..."
    adb shell input keyevent KEYCODE_POWER
}

wake_display() {
    check_connection
    log_info "Waking display..."
    adb shell input keyevent KEYCODE_WAKEUP 2>/dev/null || adb shell input keyevent KEYCODE_POWER
}

# Usage
show_usage() {
    cat << 'EOF'
display.sh - E-ink display control for Nook Simple Touch

USAGE:
    ./display.sh <command> [arguments]

COMMANDS:
    dashboard           Show ShelfCast dashboard
    url <url>           Display a URL
    html <file>         Display a local HTML file
    message <title> [body] [font_size]  Display a message
    image <file>        Display an image
    refresh             Force full e-ink refresh
    scroll [up|down]    Scroll the current page
    navigate <dir>      Navigate (up/down/left/right/select/back/home)
    sleep               Put display to sleep
    wake                Wake display

EXAMPLES:
    ./display.sh dashboard
    ./display.sh url "https://example.com"
    ./display.sh message "Hello" "Welcome to ShelfCast" 64
    ./display.sh scroll down
    ./display.sh refresh

EOF
}

# Main
main() {
    local cmd="${1:-}"

    if [[ -z "$cmd" ]] || [[ "$cmd" == "help" ]]; then
        show_usage
        exit 0
    fi

    shift

    case "$cmd" in
        dashboard)  show_dashboard ;;
        url)        show_url "$@" ;;
        html)       show_html "$@" ;;
        message)    show_message "$@" ;;
        image)      show_image "$@" ;;
        refresh)    full_refresh ;;
        scroll)     scroll "$@" ;;
        navigate)   navigate "$@" ;;
        sleep)      sleep_display ;;
        wake)       wake_display ;;
        *)
            echo "Unknown command: $cmd"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"

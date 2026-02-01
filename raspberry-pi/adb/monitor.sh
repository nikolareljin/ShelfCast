#!/usr/bin/env bash
set -euo pipefail

# Nook Connection Monitor
# Monitors USB connection and automatically sets up ShelfCast when Nook connects

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOOK_CTL="$SCRIPT_DIR/nook-ctl.sh"

# Configuration
CHECK_INTERVAL="${CHECK_INTERVAL:-5}"           # Seconds between checks
AUTO_DASHBOARD="${AUTO_DASHBOARD:-true}"        # Auto-launch dashboard on connect
AUTO_REFRESH_INTERVAL="${AUTO_REFRESH_INTERVAL:-300}"  # Auto-refresh interval (0=disabled)
LOG_FILE="${LOG_FILE:-/var/log/shelfcast-nook.log}"

# State
LAST_CONNECTED=false
LAST_REFRESH_TIME=0

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg"
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE" 2>/dev/null || true
}

log_info() { log "INFO" "$*"; }
log_warn() { log "WARN" "$*"; }
log_error() { log "ERROR" "$*"; }

# Check if Nook is connected
is_connected() {
    local devices
    devices=$(adb devices 2>/dev/null | grep -v "List" | grep -v "^$" | grep -c "device$" || echo "0")
    [[ "$devices" -gt 0 ]]
}

# Handle connection event
on_connect() {
    log_info "Nook connected!"

    # Set up port forwarding
    log_info "Setting up port forwarding..."
    adb reverse tcp:8080 tcp:8080 2>/dev/null || true

    # Launch dashboard if enabled
    if [[ "$AUTO_DASHBOARD" == "true" ]]; then
        log_info "Launching ShelfCast dashboard..."
        "$NOOK_CTL" dashboard 2>/dev/null || true
    fi

    LAST_REFRESH_TIME=$(date +%s)
}

# Handle disconnection event
on_disconnect() {
    log_warn "Nook disconnected"
}

# Periodic refresh for e-ink
do_refresh() {
    if [[ "$AUTO_REFRESH_INTERVAL" -gt 0 ]]; then
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - LAST_REFRESH_TIME))

        if [[ $elapsed -ge $AUTO_REFRESH_INTERVAL ]]; then
            log_info "Auto-refreshing display..."
            "$NOOK_CTL" refresh 2>/dev/null || true
            LAST_REFRESH_TIME=$current_time
        fi
    fi
}

# Main monitoring loop
monitor_loop() {
    log_info "Starting Nook monitor (interval: ${CHECK_INTERVAL}s)"
    log_info "Auto-dashboard: $AUTO_DASHBOARD"
    log_info "Auto-refresh: ${AUTO_REFRESH_INTERVAL}s (0=disabled)"

    # Ensure ADB server is running
    adb start-server 2>/dev/null

    while true; do
        if is_connected; then
            if [[ "$LAST_CONNECTED" == "false" ]]; then
                on_connect
                LAST_CONNECTED=true
            else
                # Already connected, check for periodic refresh
                do_refresh
            fi
        else
            if [[ "$LAST_CONNECTED" == "true" ]]; then
                on_disconnect
                LAST_CONNECTED=false
            fi
        fi

        sleep "$CHECK_INTERVAL"
    done
}

# Handle signals
cleanup() {
    log_info "Monitor stopped"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Show usage
show_usage() {
    cat << 'EOF'
Nook Connection Monitor

Monitors USB connection and automatically manages ShelfCast on Nook.

USAGE:
    ./monitor.sh [start|stop|status]

OPTIONS:
    start       Start the monitor in foreground
    stop        Stop the monitor (if running as service)
    status      Check if monitor is running

ENVIRONMENT:
    CHECK_INTERVAL          Seconds between connection checks (default: 5)
    AUTO_DASHBOARD          Auto-launch dashboard on connect (default: true)
    AUTO_REFRESH_INTERVAL   Seconds between e-ink refreshes (default: 300, 0=disabled)
    LOG_FILE                Log file path (default: /var/log/shelfcast-nook.log)

EXAMPLES:
    ./monitor.sh start                    # Start monitoring
    CHECK_INTERVAL=10 ./monitor.sh start  # Check every 10 seconds
    AUTO_DASHBOARD=false ./monitor.sh     # Don't auto-launch dashboard

EOF
}

# Main
main() {
    local cmd="${1:-start}"

    case "$cmd" in
        start)
            monitor_loop
            ;;
        stop)
            pkill -f "monitor.sh" 2>/dev/null || true
            log_info "Monitor stopped"
            ;;
        status)
            if pgrep -f "monitor.sh" > /dev/null 2>&1; then
                echo "Monitor is running"
                exit 0
            else
                echo "Monitor is not running"
                exit 1
            fi
            ;;
        -h|--help|help)
            show_usage
            ;;
        *)
            log_error "Unknown command: $cmd"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"

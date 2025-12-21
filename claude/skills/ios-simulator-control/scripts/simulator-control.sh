#!/usr/bin/env bash
# ios-simulator-control/scripts/simulator-control.sh
# Manage iOS simulators

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$HOME/.claude/skills/_shared/ios/scripts"

source "$SHARED_DIR/lib.sh"

# ============================================================================
# SIMULATOR OPERATIONS
# ============================================================================

list_simulators() {
    local runtime_filter="${1:-iOS}"

    log_info "Listing simulators (runtime: $runtime_filter)..."

    xcrun simctl list devices available -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
result = []
for runtime, devices in data['devices'].items():
    if '$runtime_filter' not in runtime:
        continue
    for device in devices:
        if device.get('isAvailable'):
            result.append({
                'name': device['name'],
                'udid': device['udid'],
                'state': device['state'],
                'runtime': runtime
            })
print(json.dumps(result, indent=2))
    "
}

boot_simulator() {
    local udid="$1"

    log_info "Booting simulator: $udid"

    xcrun simctl boot "$udid" 2>&1 || {
        log_warn "Boot failed (may already be booted)"
    }

    # Wait for boot
    local waited=0
    while [[ $waited -lt 30 ]]; do
        local state
        state=$(xcrun simctl list devices -j | python3 -c "
import json, sys
for runtime, devices in json.load(sys.stdin)['devices'].items():
    for d in devices:
        if d['udid'] == '$udid':
            print(d['state'])
            sys.exit(0)
        ")

        if [[ "$state" == "Booted" ]]; then
            log_info "Simulator booted"
            json_output "success" "Simulator booted" "{\"udid\": \"$udid\", \"state\": \"Booted\"}"
            return 0
        fi

        sleep 2
        waited=$((waited + 2))
    done

    json_output "timeout" "Simulator boot timeout" "{\"udid\": \"$udid\"}"
    return 1
}

shutdown_simulator() {
    local udid="$1"

    log_info "Shutting down simulator: $udid"
    xcrun simctl shutdown "$udid" || log_warn "Shutdown failed"

    json_output "success" "Simulator shutdown" "{\"udid\": \"$udid\"}"
}

erase_simulator() {
    local udid="$1"

    log_info "Erasing simulator: $udid"

    # Must be shutdown to erase
    xcrun simctl shutdown "$udid" 2>/dev/null || true
    sleep 2

    xcrun simctl erase "$udid"

    json_output "success" "Simulator erased" "{\"udid\": \"$udid\"}"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    require_command xcrun

    parse_args "$@"

    local command="${FLAG_positional:-list}"

    case "$command" in
        list)
            list_simulators "${FLAG_runtime:-iOS}"
            ;;
        boot)
            local udid="${FLAG_udid:-}"
            if [[ -z "$udid" ]]; then
                # Discover by name
                local name="${FLAG_device:-iPhone 16}"
                udid=$("$SHARED_DIR/discover.sh" destination --device "$name" | grep -oE 'id=[A-F0-9-]+' | cut -d= -f2)
            fi
            boot_simulator "$udid"
            ;;
        shutdown)
            shutdown_simulator "${FLAG_udid}"
            ;;
        erase)
            erase_simulator "${FLAG_udid}"
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Usage: $0 {list|boot|shutdown|erase} [options]"
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

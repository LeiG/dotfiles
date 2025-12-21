#!/usr/bin/env bash
# ios-test-ios/scripts/test-ios.sh
# Run iOS tests with detailed failure diagnostics

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$HOME/.claude/skills/_shared/ios/scripts"

source "$SHARED_DIR/lib.sh"

# ============================================================================
# SIMULATOR MANAGEMENT
# ============================================================================

# Ensure simulator is booted
ensure_simulator_booted() {
    local destination="$1"

    # Extract UDID from destination string
    local udid
    udid=$(echo "$destination" | grep -oE 'id=[A-F0-9-]+' | cut -d= -f2 || echo "")

    if [[ -z "$udid" ]]; then
        log_warn "Could not extract simulator UDID from destination"
        return 0
    fi

    # Check if already booted
    local state
    state=$(xcrun simctl list devices -j | python3 -c "
import json, sys
devices = json.load(sys.stdin)['devices']
for runtime, device_list in devices.items():
    for device in device_list:
        if device['udid'] == '$udid':
            print(device['state'])
            sys.exit(0)
    ")

    if [[ "$state" == "Booted" ]]; then
        log_debug "Simulator already booted: $udid"
        return 0
    fi

    log_info "Booting simulator: $udid"
    xcrun simctl boot "$udid" 2>&1 || log_warn "Simulator boot failed (may already be booting)"

    # Wait for boot to complete (max 30s)
    local waited=0
    while [[ $waited -lt 30 ]]; do
        state=$(xcrun simctl list devices -j | python3 -c "
import json, sys
devices = json.load(sys.stdin)['devices']
for runtime, device_list in devices.items():
    for device in device_list:
        if device['udid'] == '$udid':
            print(device['state'])
            sys.exit(0)
        ")

        if [[ "$state" == "Booted" ]]; then
            log_info "Simulator booted successfully"
            return 0
        fi

        sleep 2
        waited=$((waited + 2))
    done

    log_warn "Simulator boot timeout, proceeding anyway"
}

# ============================================================================
# TEST EXECUTION
# ============================================================================

run_tests() {
    local project_type="$1"
    local project_path="$2"
    local scheme="$3"
    local destination="$4"
    local only_testing="${5:-}"
    local slow_threshold="${6:-5.0}"

    # Boot simulator
    ensure_simulator_booted "$destination"

    log_info "Running tests for $scheme..."
    [[ -n "$only_testing" ]] && log_info "Selective: $only_testing"

    # Construct test command
    local test_cmd=(
        xcodebuild test
        "-${project_type}" "$project_path"
        -scheme "$scheme"
        -destination "$destination"
    )

    if [[ -n "$only_testing" ]]; then
        test_cmd+=(-only-testing:"$only_testing")
    fi

    # Execute
    local start_time
    start_time=$(date +%s)

    local output_file
    output_file=$(create_temp_file "test-output")

    local test_status=0
    "${test_cmd[@]}" 2>&1 | tee "$output_file" || test_status=$?

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_info "Tests completed in ${duration}s (exit code: $test_status)"

    # Parse with xcsift
    local diagnostics
    diagnostics=$(cat "$output_file" | "$SHARED_DIR/xcsift-check.sh" parse --operation test)

    # Check for crashes in simulator logs
    local crash_logs=""
    if [[ $test_status -ne 0 ]]; then
        crash_logs=$(extract_crash_logs "$destination" "$output_file")
    fi

    # Extract slow tests
    local slow_tests
    slow_tests=$(extract_slow_tests "$output_file" "$slow_threshold")

    cat <<EOF
{
  "status": $([ $test_status -eq 0 ] && echo '"success"' || echo '"failure"'),
  "test_time": $duration,
  "exit_code": $test_status,
  "diagnostics": $diagnostics,
  "crash_logs": $(json_escape "$crash_logs"),
  "slow_tests": $slow_tests
}
EOF
}

# ============================================================================
# CRASH LOG EXTRACTION
# ============================================================================

extract_crash_logs() {
    local destination="$1"
    local output_file="$2"

    # Extract UDID
    local udid
    udid=$(echo "$destination" | grep -oE 'id=[A-F0-9-]+' | cut -d= -f2 || echo "")

    if [[ -z "$udid" ]]; then
        return 0
    fi

    # Look for crash files in simulator's DiagnosticReports
    local crash_dir="$HOME/Library/Logs/CoreSimulator/$udid/DiagnosticReports"

    if [[ ! -d "$crash_dir" ]]; then
        return 0
    fi

    # Find recent crash files (last 5 minutes)
    local recent_crashes
    recent_crashes=$(find "$crash_dir" -name "*.crash" -mmin -5 2>/dev/null || true)

    if [[ -z "$recent_crashes" ]]; then
        return 0
    fi

    # Read first crash file (most relevant)
    local crash_content
    crash_content=$(echo "$recent_crashes" | head -1 | xargs cat 2>/dev/null | head -50 || echo "")

    echo "$crash_content"
}

# ============================================================================
# SLOW TEST DETECTION
# ============================================================================

extract_slow_tests() {
    local output_file="$1"
    local threshold="$2"

    # Parse test timing from xcodebuild output
    # Format: "Test Case '-[ClassName testMethod]' passed (X.XXX seconds)"
    local slow_tests
    slow_tests=$(grep -oE "Test Case.*passed \([0-9.]+[[:space:]]seconds\)" "$output_file" | \
        awk -v thresh="$threshold" '{
            match($0, /\[([^\]]+)\]/, class);
            match($0, /\(([0-9.]+)/, time);
            if (time[1] > thresh) {
                print "{\"test\": \"" class[1] "\", \"duration\": " time[1] "}"
            }
        }' || echo "")

    if [[ -z "$slow_tests" ]]; then
        echo "[]"
    else
        echo "[$slow_tests]" | sed 's/}{/},{/g'
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    require_command xcodebuild
    require_command xcrun

    parse_args "$@"

    # Similar discovery logic as build-ios.sh
    local project_path="${FLAG_project:-}"
    local workspace_path="${FLAG_workspace:-}"
    local scheme="${FLAG_scheme:-}"
    local destination="${FLAG_destination:-}"
    local only_testing="${FLAG_only_testing:-}"
    local slow_threshold="${FLAG_slow_threshold:-5.0}"
    local dir="${FLAG_dir:-$PWD}"

    # Auto-discover project
    if [[ -z "$project_path" && -z "$workspace_path" ]]; then
        local project_json
        project_json=$("$SHARED_DIR/discover.sh" project --dir "$dir")

        local project_type
        project_type=$(echo "$project_json" | python3 -c "import json, sys; print(json.load(sys.stdin)['type'])")

        if [[ "$project_type" == "workspace" ]]; then
            workspace_path=$(echo "$project_json" | python3 -c "import json, sys; print(json.load(sys.stdin)['path'])")
        else
            project_path=$(echo "$project_json" | python3 -c "import json, sys; print(json.load(sys.stdin)['path'])")
        fi
    fi

    local project_type="project"
    local project_file="$project_path"
    if [[ -n "$workspace_path" ]]; then
        project_type="workspace"
        project_file="$workspace_path"
    fi

    # Auto-discover scheme
    if [[ -z "$scheme" ]]; then
        local schemes_json
        schemes_json=$("$SHARED_DIR/discover.sh" schemes --dir "$dir")
        scheme=$(echo "$schemes_json" | python3 -c "import json, sys; schemes = json.load(sys.stdin); print(schemes[0] if schemes else '')")

        [[ -z "$scheme" ]] && { log_error "No schemes found"; exit 1; }
    fi

    # Auto-discover destination
    if [[ -z "$destination" ]]; then
        destination=$("$SHARED_DIR/discover.sh" destination)
    fi

    # Run tests
    run_tests "$project_type" "$project_file" "$scheme" "$destination" "$only_testing" "$slow_threshold"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

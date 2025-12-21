#!/usr/bin/env bash
# _shared/ios/scripts/discover.sh
# Auto-discover iOS project configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# ============================================================================
# PROJECT DISCOVERY
# ============================================================================

# Find workspace or project file
# Returns: JSON with { "type": "workspace|project", "path": "...", "name": "..." }
discover_project() {
    local search_dir="${1:-.}"
    search_dir=$(resolve_path "$search_dir")

    log_info "Discovering project in: $search_dir"

    # Prefer workspace over project (workspace includes projects)
    local workspace
    workspace=$(find "$search_dir" -maxdepth 1 -name "*.xcworkspace" -type d 2>/dev/null | head -1)

    if [[ -n "$workspace" ]]; then
        local name
        name=$(basename "$workspace" .xcworkspace)
        cat <<EOF
{
  "type": "workspace",
  "path": "$workspace",
  "name": "$name"
}
EOF
        return 0
    fi

    # Fallback to project
    local project
    project=$(find "$search_dir" -maxdepth 1 -name "*.xcodeproj" -type d 2>/dev/null | head -1)

    if [[ -n "$project" ]]; then
        local name
        name=$(basename "$project" .xcodeproj)
        cat <<EOF
{
  "type": "project",
  "path": "$project",
  "name": "$name"
}
EOF
        return 0
    fi

    log_error "No .xcworkspace or .xcodeproj found in $search_dir"
    return 1
}

# ============================================================================
# SCHEME ENUMERATION
# ============================================================================

# List all schemes for a workspace/project
# Returns: JSON array of scheme names
discover_schemes() {
    local project_type="$1"  # workspace or project
    local project_path="$2"

    log_info "Discovering schemes in $project_path"

    local flag="-workspace"
    [[ "$project_type" == "project" ]] && flag="-project"

    # xcodebuild -list outputs schemes in a specific section
    local schemes
    schemes=$(xcodebuild -list "$flag" "$project_path" 2>/dev/null | \
        awk '/Schemes:/,/^$/ {if ($0 !~ /Schemes:/ && NF>0) print $1}')

    if [[ -z "$schemes" ]]; then
        log_warn "No schemes found"
        echo "[]"
        return 0
    fi

    # Convert to JSON array
    echo -n "["
    local first=true
    while IFS= read -r scheme; do
        [[ -z "$scheme" ]] && continue
        if [[ "$first" == true ]]; then
            first=false
        else
            echo -n ","
        fi
        echo -n "\"$scheme\""
    done <<< "$schemes"
    echo "]"
}

# ============================================================================
# DESTINATION DETECTION
# ============================================================================

# Find suitable test destination (simulator)
# Priority: iPhone 16 (iOS 18.x) > Latest iPhone > Latest iPad > Any iOS Simulator
# Returns: Full destination string "platform=iOS Simulator,id=UDID"
discover_destination() {
    local preferred_device="${1:-iPhone 16}"
    local min_ios_version="${2:-18.0}"

    log_info "Finding simulator for $preferred_device (iOS >= $min_ios_version)"

    # Get available simulators as JSON
    local simulators
    simulators=$(xcrun simctl list devices available -j)

    # Extract iOS simulators with jq (if available) or Python
    local device_info
    if command -v jq &>/dev/null; then
        device_info=$(echo "$simulators" | jq -r '
            .devices
            | to_entries[]
            | select(.key | contains("iOS"))
            | .value[]
            | select(.isAvailable == true)
            | "\(.name)|\(.udid)|\(.state)|\(.deviceTypeIdentifier)"
        ')
    else
        # Python fallback
        device_info=$(echo "$simulators" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data["devices"].items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if device.get("isAvailable"):
            print(f"{device[\"name\"]}|{device[\"udid\"]}|{device[\"state\"]}|{device[\"deviceTypeIdentifier\"]}")
        ')
    fi

    # Find best match
    local best_udid=""
    local best_name=""

    # First: try exact match on preferred device
    while IFS='|' read -r name udid state devtype; do
        if [[ "$name" == "$preferred_device" ]]; then
            best_udid="$udid"
            best_name="$name"
            break
        fi
    done <<< "$device_info"

    # Fallback: any iPhone
    if [[ -z "$best_udid" ]]; then
        while IFS='|' read -r name udid state devtype; do
            if [[ "$name" =~ iPhone ]]; then
                best_udid="$udid"
                best_name="$name"
                break
            fi
        done <<< "$device_info"
    fi

    # Fallback: any iOS device
    if [[ -z "$best_udid" ]]; then
        read -r best_name best_udid _ _ <<< "$(echo "$device_info" | head -1 | tr '|' ' ')"
    fi

    if [[ -z "$best_udid" ]]; then
        log_error "No available iOS simulators found"
        return 1
    fi

    log_info "Selected: $best_name ($best_udid)"

    # Return full destination string
    echo "platform=iOS Simulator,id=$best_udid"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    parse_args "$@"

    local command="${FLAG_positional:-discover}"
    local dir="${FLAG_dir:-$PWD}"

    case "$command" in
        project)
            discover_project "$dir"
            ;;
        schemes)
            local project_json
            project_json=$(discover_project "$dir")
            local project_type project_path
            project_type=$(echo "$project_json" | python3 -c "import json, sys; print(json.load(sys.stdin)['type'])")
            project_path=$(echo "$project_json" | python3 -c "import json, sys; print(json.load(sys.stdin)['path'])")
            discover_schemes "$project_type" "$project_path"
            ;;
        destination)
            discover_destination "${FLAG_device:-iPhone 16}" "${FLAG_min_ios:-18.0}"
            ;;
        *)
            # Full discovery
            local project_json
            project_json=$(discover_project "$dir")
            echo "$project_json" | python3 -c '
import json, sys
project = json.load(sys.stdin)
# Could extend to include schemes + destination
print(json.dumps(project, indent=2))
            '
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

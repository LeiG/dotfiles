#!/usr/bin/env bash
# ios-build-ios/scripts/build-ios.sh
# Build iOS projects with diagnostics

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$HOME/.claude/skills/_shared/ios/scripts"

source "$SHARED_DIR/lib.sh"

# ============================================================================
# BUILD EXECUTION
# ============================================================================

build_project() {
    local project_type="$1"  # workspace or project
    local project_path="$2"
    local scheme="$3"
    local destination="$4"
    local configuration="${5:-Debug}"
    local clean="${6:-false}"

    log_info "Building $scheme ($configuration)..."
    log_debug "Project: $project_path"
    log_debug "Destination: $destination"

    # Construct xcodebuild command
    local build_cmd=(
        xcodebuild
        "-${project_type}" "$project_path"
        -scheme "$scheme"
        -configuration "$configuration"
        -destination "$destination"
    )

    # Add clean if requested
    if [[ "$clean" == "true" ]]; then
        build_cmd+=(clean)
    fi

    build_cmd+=(build)

    # Execute with timing
    local start_time
    start_time=$(date +%s)

    local output_file
    output_file=$(create_temp_file "build-output")

    local build_status=0
    "${build_cmd[@]}" 2>&1 | tee "$output_file" || build_status=$?

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_info "Build completed in ${duration}s (exit code: $build_status)"

    # Parse output with xcsift
    local diagnostics
    diagnostics=$(cat "$output_file" | "$SHARED_DIR/xcsift-check.sh" parse --operation build)

    # Extract status from diagnostics
    local diag_status
    diag_status=$(echo "$diagnostics" | python3 -c "import json, sys; print(json.load(sys.stdin)['status'])")

    # Determine final status with multiple signals (CRITICAL FIX)
    local final_status="success"

    # Check 1: xcodebuild exit code
    if [[ $build_status -ne 0 ]]; then
        final_status="failure"
        log_warn "Build failed (exit code: $build_status)"
    fi

    # Check 2: Parsed diagnostics
    if [[ "$diag_status" == "failure" ]]; then
        final_status="failure"
        log_warn "Build failed (diagnostics detected errors)"
    fi

    # Check 3: Scan for BUILD FAILED marker
    if grep -q "BUILD FAILED" "$output_file"; then
        final_status="failure"
        log_warn "Build failed (BUILD FAILED marker found)"
    fi

    # Check 4: Missing BUILD SUCCEEDED (suspicious if other checks pass)
    if ! grep -q "BUILD SUCCEEDED" "$output_file" && [[ "$final_status" == "success" ]]; then
        log_warn "BUILD SUCCEEDED marker not found, treating as potential failure"
        final_status="failure"
    fi

    # Extract error locations
    local error_locations
    error_locations=$(extract_error_locations "$output_file")

    # Build final output
    cat <<EOF
{
  "status": "$final_status",
  "build_time": $duration,
  "exit_code": $build_status,
  "diagnostics": $diagnostics,
  "error_locations": $error_locations,
  "validation": {
    "exit_code_status": $([ $build_status -eq 0 ] && echo '"success"' || echo '"failure"'),
    "parsed_status": "$diag_status",
    "has_build_failed_marker": $(grep -q "BUILD FAILED" "$output_file" && echo 'true' || echo 'false'),
    "has_build_succeeded_marker": $(grep -q "BUILD SUCCEEDED" "$output_file" && echo 'true' || echo 'false')
  }
}
EOF
}

# ============================================================================
# ERROR LOCATION EXTRACTION
# ============================================================================

extract_error_locations() {
    local output_file="$1"

    # Extract file:line:column patterns
    grep -oE "/[^:]+\.swift:[0-9]+:[0-9]+[[:space:]]" "$output_file" 2>/dev/null | \
        sort -u | \
        python3 -c '
import sys, json
locations = []
for line in sys.stdin:
    parts = line.strip().split(":")
    if len(parts) >= 3:
        locations.append({
            "file": parts[0],
            "line": int(parts[1]) if parts[1].isdigit() else 0,
            "column": int(parts[2]) if parts[2].isdigit() else 0
        })
print(json.dumps(locations[:10], indent=2))
        ' || echo "[]"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    require_command xcodebuild "Install Xcode Command Line Tools"

    parse_args "$@"

    # Project discovery
    local project_path="${FLAG_project:-}"
    local workspace_path="${FLAG_workspace:-}"
    local scheme="${FLAG_scheme:-}"
    local destination="${FLAG_destination:-}"
    local configuration="${FLAG_configuration:-Debug}"
    local clean="${FLAG_clean:-false}"
    local dir="${FLAG_dir:-$PWD}"

    # Auto-discover if not specified
    if [[ -z "$project_path" && -z "$workspace_path" ]]; then
        log_info "Auto-discovering project..."
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

    # Determine project type
    local project_type="project"
    local project_file="$project_path"
    if [[ -n "$workspace_path" ]]; then
        project_type="workspace"
        project_file="$workspace_path"
    fi

    # Auto-discover scheme if not specified
    if [[ -z "$scheme" ]]; then
        log_info "Auto-discovering scheme..."
        local schemes_json
        schemes_json=$("$SHARED_DIR/discover.sh" schemes --dir "$dir")
        scheme=$(echo "$schemes_json" | python3 -c "import json, sys; schemes = json.load(sys.stdin); print(schemes[0] if schemes else '')")

        if [[ -z "$scheme" ]]; then
            log_error "No schemes found. Specify --scheme explicitly."
            exit 1
        fi

        log_info "Using scheme: $scheme"
    fi

    # Auto-discover destination if not specified
    if [[ -z "$destination" ]]; then
        log_info "Auto-discovering destination..."
        destination=$("$SHARED_DIR/discover.sh" destination)
    fi

    # Execute build
    build_project "$project_type" "$project_file" "$scheme" "$destination" "$configuration" "$clean"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

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

    # Build final output
    cat <<EOF
{
  "status": "$diag_status",
  "build_time": $duration,
  "exit_code": $build_status,
  "diagnostics": $diagnostics
}
EOF
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

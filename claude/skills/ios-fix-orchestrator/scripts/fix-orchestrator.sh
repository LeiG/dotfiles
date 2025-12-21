#!/usr/bin/env bash
# ios-fix-orchestrator/scripts/fix-orchestrator.sh
# Automated fix iteration loop

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$HOME/.claude/skills/_shared/ios/scripts"

source "$SHARED_DIR/lib.sh"

# ============================================================================
# ORCHESTRATION LOOP
# ============================================================================

orchestrate_fixes() {
    local max_iterations="${1:-3}"
    local current_iteration=0
    local iterations_json="[]"

    log_info "Starting fix orchestration (max $max_iterations iterations)..."

    while [[ $current_iteration -lt $max_iterations ]]; do
        current_iteration=$((current_iteration + 1))
        log_info "=== Iteration $current_iteration/$max_iterations ==="

        # Step 1: Build
        log_info "Building project..."
        local build_result
        build_result=$("$HOME/.claude/skills/ios-build-ios/scripts/build-ios.sh")

        local build_status
        build_status=$(echo "$build_result" | python3 -c "import json, sys; print(json.load(sys.stdin)['status'])")

        if [[ "$build_status" == "success" ]]; then
            log_info "Build successful, running tests..."

            # Step 2: Test
            local test_result
            test_result=$("$HOME/.claude/skills/ios-test-ios/scripts/test-ios.sh")

            local test_status
            test_status=$(echo "$test_result" | python3 -c "import json, sys; print(json.load(sys.stdin)['status'])")

            if [[ "$test_status" == "success" ]]; then
                log_info "All tests passed! Orchestration complete."

                cat <<EOF
{
  "final_status": "fixed",
  "iterations": $current_iteration,
  "summary": "Fixed and tested successfully in $current_iteration iteration(s)"
}
EOF
                return 0
            else
                log_warn "Tests failed, analyzing..."
                # TODO: Test failure analysis and fixes
                # For now, return partial result
                cat <<EOF
{
  "final_status": "test_failures",
  "iterations": $current_iteration,
  "summary": "Build succeeded but tests are failing",
  "test_result": $test_result
}
EOF
                return 1
            fi
        else
            log_warn "Build failed, analyzing errors..."

            # Step 3: Classify errors
            local error_classification
            error_classification=$(classify_build_errors "$build_result")

            # Step 4: Attempt fixes (placeholder - LLM would generate fixes)
            log_info "Error classification: $error_classification"

            # For this implementation, we assume LLM-driven fix generation
            # would happen here via Claude Code integration

            cat <<EOF
{
  "final_status": "build_failures",
  "iterations": $current_iteration,
  "summary": "Build failed, manual intervention needed",
  "build_result": $build_result,
  "error_classification": $error_classification
}
EOF
            return 1
        fi
    done

    log_warn "Max iterations reached without resolution"
    cat <<EOF
{
  "final_status": "timeout",
  "iterations": $max_iterations,
  "summary": "Max iterations reached, manual intervention required"
}
EOF
    return 1
}

# ============================================================================
# ERROR CLASSIFICATION
# ============================================================================

classify_build_errors() {
    local build_result="$1"

    # Extract error messages
    local errors
    errors=$(echo "$build_result" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    diag = json.loads(data.get('diagnostics', '{}'))
    errors = diag.get('errors', '')
    print(errors)
except:
    pass
    ")

    # Classify errors
    local fixable=0
    local hard_blockers=0

    # Fixable: missing imports, typos, simple syntax
    if echo "$errors" | grep -qE "(cannot find.*in scope|use of undeclared|expected.*before)"; then
        fixable=$((fixable + 1))
    fi

    # Hard blockers: API changes, complex dependency issues
    if echo "$errors" | grep -qE "(No such module|framework not found|Undefined symbols)"; then
        hard_blockers=$((hard_blockers + 1))
    fi

    cat <<EOF
{
  "fixable_errors": $fixable,
  "hard_blockers": $hard_blockers,
  "recommendation": $([ $hard_blockers -gt 0 ] && echo '"manual_intervention"' || echo '"auto_fixable"')
}
EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    parse_args "$@"

    local max_iterations="${FLAG_max_iterations:-3}"

    orchestrate_fixes "$max_iterations"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

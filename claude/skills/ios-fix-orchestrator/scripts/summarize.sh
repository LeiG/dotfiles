#!/usr/bin/env bash
# ios-fix-orchestrator/scripts/summarize.sh
# Generate concise summaries of build/test results

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$HOME/.claude/skills/_shared/ios/scripts"

source "$SHARED_DIR/lib.sh"

# ============================================================================
# SUMMARIZATION
# ============================================================================

summarize_build() {
    local build_result="$1"

    local status
    status=$(echo "$build_result" | python3 -c "import json, sys; print(json.load(sys.stdin)['status'])")

    local build_time
    build_time=$(echo "$build_result" | python3 -c "import json, sys; print(json.load(sys.stdin)['build_time'])")

    if [[ "$status" == "success" ]]; then
        echo "✅ Build succeeded in ${build_time}s"
    else
        local diagnostics
        diagnostics=$(echo "$build_result" | python3 -c "import json, sys; print(json.loads(json.load(sys.stdin)['diagnostics']))")

        local errors
        errors=$(echo "$diagnostics" | python3 -c "import json, sys; print(json.load(sys.stdin)['summary']['errors'])")

        echo "❌ Build failed with $errors error(s) in ${build_time}s"
    fi
}

summarize_test() {
    local test_result="$1"

    local status
    status=$(echo "$test_result" | python3 -c "import json, sys; print(json.load(sys.stdin)['status'])")

    local test_time
    test_time=$(echo "$test_result" | python3 -c "import json, sys; print(json.load(sys.stdin)['test_time'])")

    if [[ "$status" == "success" ]]; then
        echo "✅ All tests passed in ${test_time}s"
    else
        local diagnostics
        diagnostics=$(echo "$test_result" | python3 -c "import json, sys; print(json.loads(json.load(sys.stdin)['diagnostics']))")

        local failed
        failed=$(echo "$diagnostics" | python3 -c "import json, sys; print(json.load(sys.stdin)['summary']['failed_tests'])")

        echo "❌ $failed test(s) failed in ${test_time}s"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    parse_args "$@"

    local operation="${FLAG_operation:-build}"
    local result_json="${FLAG_positional:-}"

    if [[ -z "$result_json" ]]; then
        log_error "Usage: $0 <result-json> --operation build|test"
        exit 1
    fi

    case "$operation" in
        build)
            summarize_build "$result_json"
            ;;
        test)
            summarize_test "$result_json"
            ;;
        *)
            log_error "Unknown operation: $operation"
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

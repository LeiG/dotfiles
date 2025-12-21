#!/usr/bin/env bash
# _shared/ios/scripts/xcsift-check.sh
# Verify xcsift availability and configure output format

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

# ============================================================================
# XCSIFT DETECTION
# ============================================================================

# Check if xcsift is available and return configuration
# Returns: JSON with { "available": bool, "path": "...", "version": "...", "format": "toon|json|fallback" }
check_xcsift() {
    local format_pref="${1:-toon}"  # toon, json, or auto

    local available="false"
    local xcsift_path=""
    local version=""
    local output_format="fallback"

    if command -v xcsift &>/dev/null; then
        xcsift_path=$(command -v xcsift)
        version=$(xcsift --version 2>&1 | head -1 || echo "unknown")
        available="true"

        # Prefer TOON for token efficiency
        case "$format_pref" in
            toon|auto)
                output_format="toon"
                ;;
            json)
                output_format="json"
                ;;
        esac

        log_info "xcsift found: $xcsift_path (version: $version, format: $output_format)"
    else
        log_warn "xcsift not available, using fallback parsing"
        log_warn "Install: brew install xcsift OR https://github.com/ChargePoint/xcsift"
    fi

    cat <<EOF
{
  "available": $available,
  "path": "$xcsift_path",
  "version": "$version",
  "format": "$output_format"
}
EOF
}

# ============================================================================
# OUTPUT PARSING
# ============================================================================

# Parse xcodebuild output using xcsift or fallback
# Usage: xcodebuild ... 2>&1 | parse_xcodebuild_output "build|test"
parse_xcodebuild_output() {
    local operation="${1:-build}"  # build, test
    local format="${2:-auto}"

    local xcsift_config
    xcsift_config=$(check_xcsift "$format")

    local available
    available=$(echo "$xcsift_config" | python3 -c "import json, sys; print(json.load(sys.stdin)['available'])")
    local output_format
    output_format=$(echo "$xcsift_config" | python3 -c "import json, sys; print(json.load(sys.stdin)['format'])")

    if [[ "$available" == "true" ]]; then
        # Use xcsift
        case "$output_format" in
            toon)
                xcsift -f toon
                ;;
            json)
                xcsift
                ;;
        esac
    else
        # Fallback: regex parsing
        fallback_parse_"$operation"
    fi
}

# ============================================================================
# FALLBACK PARSERS (when xcsift unavailable)
# ============================================================================

fallback_parse_build() {
    local output
    output=$(cat)

    # Enhanced error detection with multiple patterns
    local errors=0

    # Pattern 1: Standard "error:" pattern
    errors=$((errors + $(echo "$output" | grep -ci "error:" || true)))

    # Pattern 2: Swift compiler errors
    errors=$((errors + $(echo "$output" | grep -ci "invalid redeclaration" || true)))
    errors=$((errors + $(echo "$output" | grep -ci "use of unresolved" || true)))
    errors=$((errors + $(echo "$output" | grep -ci "cannot find.*in scope" || true)))
    errors=$((errors + $(echo "$output" | grep -ci "type.*does not conform" || true)))
    errors=$((errors + $(echo "$output" | grep -ci "expected.*before" || true)))

    # Pattern 3: Linker errors
    errors=$((errors + $(echo "$output" | grep -ci "undefined symbols" || true)))
    errors=$((errors + $(echo "$output" | grep -ci "ld: library not found" || true)))
    errors=$((errors + $(echo "$output" | grep -ci "ld: framework not found" || true)))

    # Pattern 4: Framework errors
    errors=$((errors + $(echo "$output" | grep -ci "framework not found" || true)))
    errors=$((errors + $(echo "$output" | grep -ci "no such module" || true)))

    # Pattern 5: Build system errors
    if echo "$output" | grep -qi "BUILD FAILED"; then
        errors=$((errors + 1))
    fi

    local status="success"
    [[ $errors -gt 0 ]] && status="failure"

    local warnings
    warnings=$(echo "$output" | grep -c "warning:" || true)

    # Extract error lines (more patterns)
    local error_lines
    error_lines=$(echo "$output" | grep -iE "(error:|invalid redeclaration|undefined symbols|framework not found|BUILD FAILED)" | head -20 || echo "")

    cat <<EOF
{
  "status": "$status",
  "summary": {
    "errors": $errors,
    "warnings": $warnings,
    "linker_errors": 0,
    "failed_tests": 0,
    "pattern_matches": "enhanced"
  },
  "errors": $(json_escape "$error_lines"),
  "warnings": "",
  "note": "Parsed with enhanced fallback regex (xcsift recommended for better accuracy)"
}
EOF
}

fallback_parse_test() {
    local output
    output=$(cat)

    # Test results parsing
    local passed
    passed=$(echo "$output" | grep -oE "Test Suite .* passed" | wc -l | xargs)
    local failed
    failed=$(echo "$output" | grep -oE "Test Case .* failed" | wc -l | xargs)

    local status="success"
    [[ $failed -gt 0 ]] && status="failure"

    # Extract failure details
    local failures
    failures=$(echo "$output" | grep -A 5 "failed" | head -50 || echo "")

    cat <<EOF
{
  "status": "$status",
  "summary": {
    "passed_tests": $passed,
    "failed_tests": $failed,
    "errors": 0,
    "warnings": 0
  },
  "failures": $(json_escape "$failures"),
  "note": "Parsed with fallback regex (xcsift recommended)"
}
EOF
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    parse_args "$@"

    local command="${FLAG_positional:-check}"

    case "$command" in
        check)
            check_xcsift "${FLAG_format:-auto}"
            ;;
        parse)
            parse_xcodebuild_output "${FLAG_operation:-build}" "${FLAG_format:-auto}"
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Usage: $0 check|parse [--format toon|json|auto] [--operation build|test]"
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

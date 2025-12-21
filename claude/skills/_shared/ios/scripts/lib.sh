#!/usr/bin/env bash
# _shared/ios/scripts/lib.sh
# Version: 1.0.0
# Core utilities for iOS development skills

set -euo pipefail

# ============================================================================
# LOGGING
# ============================================================================

readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

# Default log level (INFO)
IOS_LOG_LEVEL="${IOS_LOG_LEVEL:-$LOG_LEVEL_INFO}"

log_debug() {
    [[ $IOS_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] && echo "[DEBUG] $*" >&2
}

log_info() {
    [[ $IOS_LOG_LEVEL -le $LOG_LEVEL_INFO ]] && echo "[INFO] $*" >&2
}

log_warn() {
    [[ $IOS_LOG_LEVEL -le $LOG_LEVEL_WARN ]] && echo "[WARN] $*" >&2
}

log_error() {
    [[ $IOS_LOG_LEVEL -le $LOG_LEVEL_ERROR ]] && echo "[ERROR] $*" >&2
}

# ============================================================================
# JSON OUTPUT HELPERS
# ============================================================================

# Escape JSON string (handles quotes, newlines, backslashes)
json_escape() {
    local str="$1"
    # Use Python for robust JSON escaping
    python3 -c "import json, sys; print(json.dumps(sys.argv[1]), end='')" "$str"
}

# Output structured JSON result
# Usage: json_output "success" "Build completed" '{"warnings": 2}'
json_output() {
    local status="$1"
    local message="$2"
    local data="${3:-{}}"

    cat <<EOF
{
  "status": "$status",
  "message": $(json_escape "$message"),
  "data": $data,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# ============================================================================
# PATH UTILITIES
# ============================================================================

# Resolve absolute path (handles relative paths, ~, symlinks)
resolve_path() {
    local path="$1"

    # Expand tilde
    path="${path/#\~/$HOME}"

    # Convert to absolute
    if [[ "$path" != /* ]]; then
        path="$PWD/$path"
    fi

    # Resolve symlinks and normalize
    if command -v realpath &>/dev/null; then
        realpath "$path" 2>/dev/null || echo "$path"
    elif command -v python3 &>/dev/null; then
        python3 -c "import os; print(os.path.realpath('$path'))" 2>/dev/null || echo "$path"
    else
        echo "$path"
    fi
}

# Check if path exists
require_path() {
    local path="$1"
    local type="${2:-file}"  # file, dir, any

    if [[ ! -e "$path" ]]; then
        log_error "Required path not found: $path"
        return 1
    fi

    case "$type" in
        file)
            if [[ ! -f "$path" ]]; then
                log_error "Not a file: $path"
                return 1
            fi
            ;;
        dir)
            if [[ ! -d "$path" ]]; then
                log_error "Not a directory: $path"
                return 1
            fi
            ;;
    esac

    return 0
}

# ============================================================================
# COMMAND VALIDATION
# ============================================================================

# Check if command exists
require_command() {
    local cmd="$1"
    local install_hint="${2:-}"

    if ! command -v "$cmd" &>/dev/null; then
        log_error "Required command not found: $cmd"
        [[ -n "$install_hint" ]] && log_error "Install: $install_hint"
        return 1
    fi

    log_debug "Found $cmd: $(command -v "$cmd")"
    return 0
}

# ============================================================================
# ARGUMENT PARSING (Bash 3.2 compatible)
# ============================================================================

# Parse flags and positional arguments
# Usage:
#   parse_args "$@"
#   # Access via FLAG_project, FLAG_verbose, etc.
#   project="${FLAG_project:-}"
#   verbose="${FLAG_verbose:-false}"
parse_args() {
    FLAG_positional=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --*=*)
                # Handle --key=value
                local key="${1#--}"
                key="${key%%=*}"
                local value="${1#*=}"
                key="${key//-/_}"  # Replace - with _ for variable names
                eval "FLAG_${key}='${value}'"
                shift
                ;;
            --*)
                # Handle --key value or --flag
                local key="${1#--}"
                key="${key//-/_}"  # Replace - with _ for variable names
                if [[ $# -gt 1 && ! "$2" =~ ^-- ]]; then
                    eval "FLAG_${key}='${2}'"
                    shift 2
                else
                    eval "FLAG_${key}='true'"
                    shift
                fi
                ;;
            *)
                # Positional argument
                if [[ -z "$FLAG_positional" ]]; then
                    FLAG_positional="$1"
                else
                    FLAG_positional="$FLAG_positional $1"
                fi
                shift
                ;;
        esac
    done

    export FLAG_positional
}

# ============================================================================
# TEMP FILE MANAGEMENT
# ============================================================================

# Create temp file with cleanup trap
# Returns path in TEMP_FILE variable
create_temp_file() {
    local prefix="${1:-ios-skill}"
    TEMP_FILE=$(mktemp "/tmp/${prefix}.XXXXXX")

    # Register cleanup on exit
    trap "rm -f '$TEMP_FILE'" EXIT INT TERM

    log_debug "Created temp file: $TEMP_FILE"
    echo "$TEMP_FILE"
}

# ============================================================================
# TIMEOUT EXECUTION
# ============================================================================

# Execute command with timeout
# Usage: run_with_timeout 300 xcodebuild test ...
run_with_timeout() {
    local timeout="$1"
    shift

    if command -v timeout &>/dev/null; then
        timeout "$timeout" "$@"
    elif command -v gtimeout &>/dev/null; then
        gtimeout "$timeout" "$@"
    else
        # Fallback: no timeout enforcement
        log_warn "timeout command not available, running without timeout"
        "$@"
    fi
}

#!/usr/bin/env bash
# ios-fix-orchestrator/scripts/apply-diff.sh
# Git-aware patch application with rollback support

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARED_DIR="$HOME/.claude/skills/_shared/ios/scripts"

source "$SHARED_DIR/lib.sh"

# ============================================================================
# PATCH APPLICATION
# ============================================================================

apply_patch() {
    local patch_file="$1"
    local rollback_on_fail="${2:-true}"

    log_info "Applying patch: $patch_file"

    # Check if in git repo
    if ! git rev-parse --git-dir &>/dev/null; then
        log_warn "Not in a git repository, proceeding without git integration"
        patch -p1 < "$patch_file"
        return $?
    fi

    # Save current state
    local stash_created=false
    if ! git diff --quiet; then
        log_info "Stashing current changes..."
        git stash push -m "auto-stash before apply-diff" &>/dev/null
        stash_created=true
    fi

    # Apply patch
    if git apply --check "$patch_file" 2>/dev/null; then
        git apply "$patch_file"
        log_info "Patch applied successfully"

        # Restore stash if created
        if [[ "$stash_created" == "true" ]]; then
            git stash pop &>/dev/null || log_warn "Could not restore stash"
        fi

        json_output "success" "Patch applied" "{\"patch\": \"$patch_file\"}"
        return 0
    else
        log_error "Patch failed to apply"

        if [[ "$rollback_on_fail" == "true" ]]; then
            log_info "Rolling back changes..."
            git checkout . &>/dev/null || true

            if [[ "$stash_created" == "true" ]]; then
                git stash pop &>/dev/null || log_warn "Could not restore stash"
            fi
        fi

        json_output "failure" "Patch failed to apply" "{\"patch\": \"$patch_file\"}"
        return 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    parse_args "$@"

    local patch_file="${FLAG_positional:-}"
    local rollback="${FLAG_rollback:-true}"

    if [[ -z "$patch_file" ]]; then
        log_error "Usage: $0 <patch-file> [--rollback true|false]"
        exit 1
    fi

    require_path "$patch_file" file

    apply_patch "$patch_file" "$rollback"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

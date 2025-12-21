# ios-fix-orchestrator

Automated build-fix-test feedback loop with intelligent error classification.

## When to Use

- User requests "fix build errors", "debug test failures", or "iterate until tests pass"
- After making substantial changes that may have introduced errors
- Automating repetitive fix-rebuild cycles

## Capabilities

- Runs build → analyze → fix → test loop (max 3 iterations)
- Classifies errors: fixable (missing imports, typos), hard blockers (API changes)
- Applies patches with git-aware rollback
- Summarizes changes and provides actionable next steps
- Detects flaky tests and suggests retries

## Usage

Start orchestration:
```bash
~/.claude/skills/ios-fix-orchestrator/scripts/fix-orchestrator.sh \
  --max-iterations 3
```

## Output Format

Returns JSON with:
- `iterations`: Array of { build_result, fixes_applied, test_result }
- `final_status`: "fixed", "stuck", or "timeout"
- `summary`: Human-readable summary of changes

## Dependencies

- ios-build-ios, ios-test-ios skills
- git (for patch management)

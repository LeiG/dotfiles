# ios-test-ios

Execute iOS tests and diagnose test failures.

## When to Use

- User requests to "run tests", "test this feature", or "check if tests pass"
- After making code changes to verify correctness
- Debugging test failures or flaky tests
- Selective test execution (single class or method)

## Capabilities

- Runs unit tests (XCTest) and UI tests
- Selective execution: all tests, single class, single method
- Extracts failing assertions with context (file, line, reason)
- Detects crashes and provides crash logs
- Identifies slow/flaky tests (configurable threshold)
- Auto-boots simulator if needed

## Usage

Invoke this skill when:
1. User asks to run tests
2. Verifying that code changes didn't break tests
3. Debugging specific test failures

Do NOT invoke for:
- Build-only operations (use ios-build-ios)
- Production app deployment

## Output Format

Returns JSON with:
- `status`: "success", "failure", or "crashed"
- `summary`: Passed/failed test counts, duration
- `failures`: Array of { test, assertion, file, line, reason }
- `crashes`: Crash logs if tests crashed
- `slow_tests`: Tests exceeding threshold

## Example

Run all tests:
```bash
~/.claude/skills/ios-test-ios/scripts/test-ios.sh
```

Run specific test class:
```bash
~/.claude/skills/ios-test-ios/scripts/test-ios.sh \
  --only-testing VideoPlayerViewModelTests
```

Run specific test method:
```bash
~/.claude/skills/ios-test-ios/scripts/test-ios.sh \
  --only-testing VideoPlayerViewModelTests/testPlaybackSpeed
```

## Dependencies

- xcodebuild
- xcrun simctl (simulator control)
- xcsift (recommended)

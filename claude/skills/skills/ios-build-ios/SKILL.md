# ios-build-ios

Build iOS projects and diagnose build failures.

## When to Use

- User requests to "build the app", "compile", or "check for build errors"
- After making code changes that might affect compilation
- Before running tests to ensure project compiles
- When investigating linker errors or dependency issues

## Capabilities

- Auto-detects workspace vs project files
- Builds for iOS Simulator (faster than device builds)
- Parses build output using xcsift (TOON format for token efficiency)
- Categorizes errors: compile errors, linker errors, Swift errors
- Provides actionable diagnostics with file/line numbers

## Usage

Invoke this skill when:
1. User explicitly asks to build
2. You've made code changes and need to verify compilation
3. Tests are failing due to build issues

Do NOT invoke this skill for:
- Running tests (use ios-test-ios instead)
- Simulator management (use ios-simulator-control)

## Output Format

Returns JSON with:
- `status`: "success" or "failure"
- `summary`: Error/warning counts
- `diagnostics`: Structured error details (file, line, message, type)
- `build_time`: Duration in seconds
- `raw_output`: Full xcodebuild output (if --verbose)

## Example

To build the current project:
```bash
~/.claude/skills/ios-build-ios/scripts/build-ios.sh
```

To build with specific configuration:
```bash
~/.claude/skills/ios-build-ios/scripts/build-ios.sh \
  --project /path/to/App.xcodeproj \
  --scheme MyApp \
  --configuration Debug \
  --clean
```

## Dependencies

- xcodebuild (Xcode Command Line Tools)
- xcsift (recommended, falls back to regex parsing)
- Shared scripts: discover.sh, xcsift-check.sh

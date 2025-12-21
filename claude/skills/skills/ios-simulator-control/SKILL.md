# ios-simulator-control

Manage iOS simulators (boot, shutdown, erase, install apps).

## When to Use

- User asks to "reset the simulator", "clear simulator data", or "install the app"
- Before running tests that require clean state
- Debugging simulator-specific issues
- Managing simulator lifecycle for test stability

## Capabilities

- List available simulators with detailed info
- Boot/shutdown simulators
- Erase simulator data (factory reset)
- Install apps (.app bundles)
- Launch apps with custom arguments
- Retrieve simulator logs

## Usage

List simulators:
```bash
~/.claude/skills/ios-simulator-control/scripts/simulator-control.sh list
```

Boot simulator:
```bash
~/.claude/skills/ios-simulator-control/scripts/simulator-control.sh boot \
  --device "iPhone 16"
```

Erase simulator:
```bash
~/.claude/skills/ios-simulator-control/scripts/simulator-control.sh erase \
  --udid ABC-123
```

## Output Format

Returns JSON with operation results and simulator state.

## Dependencies

- xcrun simctl

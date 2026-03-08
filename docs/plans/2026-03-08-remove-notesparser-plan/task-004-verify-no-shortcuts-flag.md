# Task 004: Verify --no-shortcuts Flag Propagation

## Overview
Verify that the `--no-shortcuts` global flag is defined but not wired through.

## Goal
Confirm the flag exists in definitions but doesn't control service behavior.

## Files to Verify
- `Sources/event/main.swift` - Global flag definition
- `Sources/event/Commands/ReminderCommands.swift` - Flag handling
- `Sources/event/Services/ReminderService.swift` - useShortcuts parameter

## Verification Steps

### Manual Test
```bash
# Test 1: Check if flag is recognized at top level
.build/debug/event --help | grep -A2 "no-shortcuts"

# Test 2: Try creating with --no-shortcuts and tags
# If properly wired: should NOT call shortcut, should show note
# If not wired: will still call shortcut (broken)
.build/debug/event --no-shortcuts reminders create --title "Test" --tags "test"
```

### Code Review
1. In `main.swift`: Flag `noShortcuts` is defined
2. In `ReminderCommands`: Check if `useShortcuts` is hardcoded to `true`
3. In `ReminderService.createReminder()`: `useShortcuts` parameter

## BDD Scenario

```gherkin
Scenario: Global --no-shortcuts flag exists
  Given the user runs "event --help"
  Then the --no-shortcuts flag should appear in help output
```

## Depends On
- task-003-verify-shortcut-integration

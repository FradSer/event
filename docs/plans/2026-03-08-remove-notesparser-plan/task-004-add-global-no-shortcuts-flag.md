# Task 004: Add Global --no-shortcuts Flag

## Overview
Add a global flag to disable Shortcut usage across all commands.

## BDD Scenario

```gherkin
Scenario: User disables shortcuts globally
  Given the CLI has --no-shortcuts flag
  When user runs "event --no-shortcuts reminders list"
  Then ShortcutsService should never be called

Scenario: Shortcuts enabled by default
  Given no --no-shortcuts flag
  When user runs "event reminders list"
  Then ShortcutsService can be called if needed
```

## Files
- Modify: `Sources/event/main.swift`

## Steps
1. Add `@Flag(name: .shortAndLong, inverted: true, help: "Disable Shortcut integration") var noShortcuts: Bool` to EventCLI struct
2. Pass this flag down to services (may need to modify service constructors or use environment/global state)

## Implementation Note
Consider using a global configuration object or passing through command context. The flag needs to be accessible in ReminderService.

## Verification
```bash
# Test flag exists
.build/debug/event --help
# Should show: --no-shortcuts    Disable Shortcut integration

# Test flag works (build must pass first)
swift build
.build/debug/event --no-shortcuts reminders list
# Should work without calling ShortcutsService
```

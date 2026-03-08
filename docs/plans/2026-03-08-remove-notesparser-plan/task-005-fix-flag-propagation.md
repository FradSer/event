# Task 005: Fix --no-shortcuts Flag Propagation

## Overview
Wire the `--no-shortcuts` global flag through to ReminderService.

## Goal
Ensure the `--no-shortcuts` flag works at both global and command level.

## Files to Modify
- `Sources/event/main.swift` - Change from @Flag to @Option
- `Sources/event/Commands/ReminderCommands.swift` - Accept flag and pass to service

## Implementation Details

### Step 1: Update main.swift
Change `@Flag` to `@Option` to allow subcommand access:

```swift
struct EventCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(...)

    @Option(name: .shortAndLong, help: "Disable Shortcut integration")
    var noShortcuts: Bool = false
}
```

### Step 2: Update ReminderCommands
Accept flag and pass to service:

```swift
struct ReminderCommands: AsyncParsableCommand {
    @Option(name: .shortAndLong, help: "Disable Shortcut integration")
    var noShortcuts: Bool = false

    // In Create.run():
    useShortcuts: !noShortcuts

    // In Update.run():
    useShortcuts: !noShortcuts
}
```

### Step 3: Apply same to CalendarCommands (if needed)
Check if CalendarCommands uses shortcuts and apply same pattern.

## Verification

```bash
# Rebuild
swift build

# Test 1: Global flag
.build/debug/event --no-shortcuts reminders create --title "Test" --tags "test"
# Expected: Reminder created, no shortcut called, note shown

# Test 2: Command-level flag
.build/debug/event reminders --no-shortcuts create --title "Test" --tags "test"
# Expected: Same as above

# Test 3: Default (shortcuts enabled)
.build/debug/event reminders create --title "Test" --tags "test"
# Expected: Shortcut called if available
```

## BDD Scenario

```gherkin
Scenario: User disables shortcuts globally
  Given the user runs "event --no-shortcuts reminders create --title 'Test'"
  When the reminder is created with tags
  Then the Shortcut should NOT be called
  And a note should inform the user that advanced fields require Shortcut

Scenario: User disables shortcuts at command level
  Given the user runs "event reminders --no-shortcuts create --title 'Test'"
  When the reminder is created with tags
  Then the Shortcut should NOT be called

Scenario: Shortcuts enabled by default
  Given the user runs "event reminders create --title 'Test' --tags 'test'"
  When the reminder is created
  Then the AdvancedReminderEdit Shortcut should be called if installed
```

## Depends On
- task-004-verify-no-shortcuts-flag

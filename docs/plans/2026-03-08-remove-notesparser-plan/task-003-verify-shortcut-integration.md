# Task 003: Verify Shortcut Integration Works

## Overview
Verify that tags, flagged, and URL are handled via Shortcut when available.

## Goal
Confirm the shortcut integration flow is correctly implemented.

## Files to Verify
- `Sources/event/Services/ShortcutsService.swift` - Exists with required methods
- `Sources/event/Models/ShortcutPayload.swift` - AdvancedReminderEditPayload exists
- `Sources/event/Services/ReminderService.swift` - Post-process logic exists

## Verification Steps

### Code Review
```bash
# Verify ShortcutsService has required methods
grep -E "(isShortcutInstalled|runShortcut)" Sources/event/Services/ShortcutsService.swift

# Verify payload model
grep -A10 "AdvancedReminderEditPayload" Sources/event/Models/ShortcutPayload.swift

# Verify ReminderService calls shortcut
grep -A5 "postProcessReminder" Sources/event/Services/ReminderService.swift
```

### Manual Test (if shortcut installed)
```bash
# Create reminder with tags (requires shortcut)
.build/debug/event reminders create --title "Test Tags" --tags "shopping,food"

# Create reminder with flagged
.build/debug/event reminders create --title "Test Flagged" --flagged
```

## BDD Scenario

```gherkin
Scenario: Create reminder with tags via Shortcut
  Given the AdvancedReminderEdit shortcut is installed
  When creating a reminder with --tags "shopping,food"
  Then the Shortcut should be called with tags in payload

Scenario: Create reminder with flagged via Shortcut
  Given the AdvancedReminderEdit shortcut is installed
  When creating a reminder with --flagged
  Then the Shortcut should be called with isFlagged="Yes"

Scenario: Shortcut not installed shows message
  Given the AdvancedReminderEdit shortcut is NOT installed
  When creating a reminder with --tags "test"
  Then a message should inform the user about the missing shortcut
```

## Depends On
- task-002-verify-subtasks-removed

# Task 006: Verify --parentTitle Still Works via Shortcut

## Overview
Verify that creating subtasks via --parentTitle still works through Shortcut.

## Goal
Confirm that --parentTitle parameter is passed to Shortcut payload.

## Files to Verify
- `Sources/event/Commands/ReminderCommands.swift` - --parentTitle option exists
- `Sources/event/Services/ReminderService.swift` - parentTitle in postProcessReminder call

## Verification Steps

### Code Review
```bash
# Verify --parentTitle option exists
grep -B2 -A2 "parentTitle" Sources/event/Commands/ReminderCommands.swift

# Verify it's passed to shortcut payload
grep -A3 "parentTitle:" Sources/event/Models/ShortcutPayload.swift
```

### Manual Test
```bash
# Create parent reminder first
PARENT_ID=$(.build/debug/event reminders create --title "Parent Task" --json | jq -r '.[0].id')

# Create child with parentTitle
.build/debug/event reminders create --title "Child Task" --parentTitle "Parent Task"
```

## BDD Scenario

```gherkin
Scenario: Create subtask via --parentTitle
  Given the AdvancedReminderEdit shortcut is installed
  When creating a reminder with --parentTitle "Parent Task"
  Then the Shortcut should be called with parentTitle in payload
  And the reminder should be linked to the parent
```

## Depends On
- task-005-fix-flag-propagation

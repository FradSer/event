# Task 002: Verify Subtask Commands Removed

## Overview
Verify that subtask-related commands and services have been removed.

## Goal
Confirm `reminders subtasks` subcommand no longer exists.

## Files to Verify
- `Sources/event/Commands/ReminderCommands.swift` - No Subtasks subcommand
- `Sources/` - No SubtaskService.swift or Subtask model

## Verification Steps

### Code Review
```bash
# Check ReminderCommands subcommands
grep -A5 "subcommands" Sources/event/Commands/ReminderCommands.swift

# Verify no subtask files
ls Sources/event/Services/SubtaskService.swift 2>/dev/null || echo "SubtaskService removed"
ls Sources/event/Models/Subtask.swift 2>/dev/null || echo "Subtask model removed"
```

### Manual Test
```bash
# Try to run subtasks command (should fail)
.build/debug/event reminders subtasks list 2>&1 || echo "Command removed"
```

## BDD Scenario

```gherkin
Scenario: Subtask commands are removed
  Given the user runs "event reminders subtasks list"
  Then the command should fail with unknown subcommand error
  And SubtaskService.swift should not exist
  And Subtask model should not exist
```

## Depends On
- task-001-verify-notesparser-removed

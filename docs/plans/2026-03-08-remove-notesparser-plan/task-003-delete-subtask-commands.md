# Task 003: Delete SubtaskCommands

## Overview
Remove SubtaskCommands from ReminderCommands and delete SubtaskCommands.swift file.

## BDD Scenario

```gherkin
Scenario: Remove subtask commands
  Given SubtaskCommands is registered as subcommand
  When I remove it from ReminderCommands.subcommands
  Then "reminders subtasks" command should not exist
  And SubtaskCommands.swift should be deleted
```

## Files
- Modify: `Sources/event/Commands/ReminderCommands.swift`
- Delete: `Sources/event/Commands/SubtaskCommands.swift`

## Steps
1. Edit ReminderCommands.swift to remove SubtaskCommands.self from subcommands array
2. Delete SubtaskCommands.swift file

## Verification
```bash
.build/debug/event reminders subtasks list
# Should return: error: unexpected argument 'subtasks'
```

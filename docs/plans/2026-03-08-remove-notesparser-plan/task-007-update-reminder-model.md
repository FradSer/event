# Task 007: Update Reminder Model and Delete Subtask Model

## Overview
Remove NotesParser parsing from Reminder model and delete Subtask model.

## BDD Scenario

```gherkin
Scenario: Reminder no longer parses tags/subtasks from notes
  Given a Reminder is created from EKReminder
  When the model is initialized
  Then tags should be nil (not parsed from notes)
  And subtasks should be removed from the model
```

## Files
- Modify: `Sources/event/Models/Reminder.swift`
- Delete: `Sources/event/Models/Subtask.swift`

## Changes Required

1. In Reminder.init(from:):
   - Remove NotesParser.parse() call
   - Remove tags assignment
   - Remove subtasks from Reminder struct (or set to empty)

2. Delete Subtask.swift entirely

3. Check MarkdownFormatter for subtask formatting code - may need to update or remove

## Verification
```bash
swift build
# Should compile without NotesParser
```

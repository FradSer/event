# Task 008: Update MarkdownFormatter - Remove Subtask Formatting

## Overview
Remove subtask-related formatting code from MarkdownFormatter.

## BDD Scenario

```gherkin
Scenario: MarkdownFormatter no longer formats subtasks
  Given MarkdownFormatter has subtask formatting methods
  When reminder is formatted
  Then subtask information should not be displayed
```

## Files
- Modify: `Sources/event/Formatters/MarkdownFormatter.swift`

## Changes Required

1. Remove subtask-related code:
   - Line 20-21: `else if let subtasks = data as? [Subtask]`
   - Line 69-71: Subtask count in reminder list
   - Line 118-122: Subtask list in reminder details
   - Line 232-244: Entire formatSubtasks method

2. Since Reminder no longer has subtasks property, also remove:
   - `parsed.subtasks` references

## Verification
```bash
swift build
# Should compile without Subtask references
```

# Task 009: Update MarkdownFormatter - Remove NotesParser Tags Parsing

## Overview
Remove NotesParser usage from MarkdownFormatter for displaying tags in reminders.

## BDD Scenario

```gherkin
Scenario: MarkdownFormatter no longer parses tags from notes
  Given a reminder has notes with tags metadata
  When the reminder is formatted
  Then tags should not be displayed (since tags now come from Shortcut)
```

## Files
- Modify: `Sources/event/Formatters/MarkdownFormatter.swift`

## Changes Required

1. Remove NotesParser.parse() calls in MarkdownFormatter:
   - Line 62: `let parsed = NotesParser.parse(notes)` for reminder list
   - Line 111: `let parsed = NotesParser.parse(notes)` for reminder details

2. These were used to display tags in reminder output. Since tags now come via Shortcut and are not stored in notes, this parsing is no longer needed.

## Verification
```bash
swift build
# Should compile without NotesParser references
```

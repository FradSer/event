# Plan: Remove NotesParser

## Overview

Remove NotesParser from the codebase and migrate tag/flag/url handling to Shortcut-based approach.

## Goals

1. Delete NotesParser.swift entirely
2. Delete SubtaskService.swift and related commands
3. Add global `--no-shortcuts` flag
4. Update ReminderService to use Shortcut for advanced fields (tags, flagged, url, parentTitle)
5. Graceful fallback when Shortcut is unavailable

## Architecture Changes

- **EventKit fields**: title, notes, dueDate, priority, completed (direct)
- **Shortcut fields**: tags, flagged, url, parentTitle (via AdvancedReminderEdit)
- **Fallback**: When Shortcut unavailable or --no-shortcuts used, advanced fields are silently skipped

## Dependencies

All tasks are independent and can be executed in any order, but recommended order follows the dependency chain naturally.

## Execution Plan

- [Task 001: Delete NotesParser.swift](./task-001-delete-notesparser.md)
- [Task 002: Delete SubtaskService.swift](./task-002-delete-subtask-service.md)
- [Task 003: Delete SubtaskCommands](./task-003-delete-subtask-commands.md)
- [Task 004: Add Global --no-shortcuts Flag](./task-004-add-global-no-shortcuts-flag.md)
- [Task 005: Update ReminderService Shortcut Flow](./task-005-update-reminder-service-shortcut-flow.md)
- [Task 006: Delete Related Test Files](./task-006-delete-related-tests.md)
- [Task 007: Update Reminder Model and Delete Subtask Model](./task-007-update-reminder-model.md)
- [Task 008: Update MarkdownFormatter - Remove Subtask Formatting](./task-008-update-markdown-formatter.md)
- [Task 009: Update MarkdownFormatter - Remove NotesParser Tags Parsing](./task-009-update-markdown-formatter-notes-parsing.md)
- [Task 010: Delete SubtaskTests.swift](./task-010-delete-subtask-tests.md)

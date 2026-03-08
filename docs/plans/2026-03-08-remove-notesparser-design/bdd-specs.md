# BDD Specifications: Remove NotesParser

## Overview

Remove NotesParser from the codebase and migrate tag/flag/url handling to Shortcut-based approach. EventKit does not support tags, flagged status, or URL directly, so these must be handled via Shortcut when available, with graceful fallback when not.

## User Stories

### Story 1: Remove NotesParser Dependency
As a developer, I want to remove NotesParser entirely so that tags, subtasks, and flagged status are no longer stored in the notes field.

**Acceptance Criteria:**
- NotesParser.swift is deleted
- No code references NotesParser
- Tags, flagged, URL operations use Shortcut exclusively

### Story 2: Shortcut-Based Tag/Flag/URL Operations
As a user, I want tags, flagged status, and URL to be set via Shortcut when available.

**Acceptance Criteria:**
- When AdvancedReminderEdit shortcut is installed, tags/flagged/url are set via Shortcut
- When shortcut is not installed, these fields are silently skipped
- User is informed when shortcut is not available

### Story 3: Global --no-shortcuts Flag
As a user, I want to disable Shortcut usage entirely via a global flag.

**Acceptance Criteria:**
- `--no-shortcuts` global flag disables all Shortcut calls
- When flag is used, only EventKit-native fields are processed
- Flag works on all subcommands

### Story 4: Remove Subtask Commands
As a user, I understand that subtask functionality is removed since it relied on NotesParser.

**Acceptance Criteria:**
- `reminders subtasks` subcommand is removed
- SubtaskService.swift is deleted
- --parentTitle parameter still works via Shortcut

## Technical Constraints

- EventKit only supports: title, notes, dueDate, priority, completed, calendar, URL
- EventKit does NOT support: tags, flagged status, subtasks
- AdvancedReminderEdit Shortcut handles: tags, flagged, url, parentTitle
- Existing ShortcutsService can be reused

## Edge Cases

1. Shortcut installed but fails → fallback to EventKit-only (no tags/flagged/url set)
2. Shortcut not installed → silently skip tags/flagged/url, continue with EventKit fields
3. --no-shortcuts flag used → same as shortcut not installed
4. Reminder created without tags/flagged/url → no Shortcut call needed

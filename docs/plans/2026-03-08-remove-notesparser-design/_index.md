# Remove NotesParser Design

## Overview

Remove NotesParser from the codebase and migrate tag/flag/url handling to Shortcut-based approach. EventKit does not support tags, flagged status, or URL directly, so these must be handled via Shortcut when available, with graceful fallback when not.

## Goals

1. Delete NotesParser.swift entirely
2. Delete SubtaskService.swift and related commands
3. Add global `--no-shortcuts` flag
4. Update ReminderService to use Shortcut for advanced fields (tags, flagged, url, parentTitle)
5. Graceful fallback when Shortcut is unavailable

## Key Documents

- [BDD Specifications](./bdd-specs.md) - User stories and acceptance criteria
- [Architecture](./architecture.md) - Technical architecture and design details
- [Best Practices](./best-practices.md) - Implementation guidelines and patterns

## Quick Links

### Commands

```bash
# Create reminder with tags (requires Shortcut)
event reminders create --title "Buy milk" --tags "shopping,groceries"

# Create reminder without Shortcut
event --no-shortcuts reminders create --title "Buy milk"

# Update with flagged status
event reminders update --id <ID> --flagged
```

### Shortcut

- **Name**: AdvancedReminderEdit
- **URL**: https://www.icloud.com/shortcuts/b578334075754da9ba6e50b501515808

## Status

- **Phase**: Completed
- **Last Updated**: 2026-03-08

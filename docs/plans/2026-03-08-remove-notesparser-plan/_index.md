# Remove NotesParser Implementation Plan

## Overview

Execute the removal of NotesParser and implement Shortcut-based tag/flag/url handling.

## Status

- **Phase**: Ready for Execution
- **Design**: [Remove NotesParser Design](../2026-03-08-remove-notesparser-design/)

## Background

Based on code review of current state:

| Story | Status |
|-------|--------|
| Story 1: Remove NotesParser Dependency | 🔲 Verify |
| Story 2: Shortcut-Based Tag/Flag/URL Operations | 🔲 Verify |
| Story 3: Global --no-shortcuts Flag | 🔲 Fix |
| Story 4: Remove Subtask Commands | 🔲 Verify |

## Execution Plan

### Verification Tasks
- [Task 001: Verify NotesParser Removed](./task-001-verify-notesparser-removed.md)
- [Task 002: Verify Subtasks Commands Removed](./task-002-verify-subtasks-removed.md)
- [Task 003: Verify Shortcut Integration](./task-003-verify-shortcut-integration.md)
- [Task 004: Verify --no-shortcuts Flag](./task-004-verify-no-shortcuts-flag.md)

### Implementation Tasks
- [Task 005: Fix Flag Propagation](./task-005-fix-flag-propagation.md)

### Final Verification
- [Task 006: Verify --parentTitle Works](./task-006-verify-parent-title.md)

## Verification

Run the CLI to test:
```bash
swift build
```

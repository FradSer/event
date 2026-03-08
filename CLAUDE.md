# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build the project
swift build

# Build release version
swift build -c release

# Run the CLI without installation
.build/debug/event --help
.build/debug/event reminders list
.build/debug/event reminders list --json   # all commands support --json flag
.build/debug/event calendar list

# Install to system
swift build -c release
sudo cp .build/release/event /usr/local/bin/

# Clean build artifacts
swift package clean

# Format code
swift format --in-place --recursive Sources Package.swift
```

## Architecture

This is a pure Swift CLI tool for managing Apple Reminders and Calendar via EventKit. The architecture follows a layered pattern: Commands → Services → EventKit, with Models and Formatters as cross-cutting concerns.

### Key Architectural Decisions

**Swift Concurrency with Actors**: All services use `actor` for thread-safe EventKit access. EventKit's `EKEventStore` is not thread-safe, so each service maintains its own store instance within an actor:

```swift
actor ReminderService {
    private let eventStore = EKEventStore()
    // All EventKit operations are serialized through the actor
}
```

**ArgumentParser Integration**: The CLI uses Swift ArgumentParser with a hierarchical command structure. The `@main` attribute requires the `-parse-as-library` compiler flag (set in Package.swift) to avoid conflicts with top-level code.

**Data Storage Workarounds**: EventKit does not expose public APIs for tags or subtasks. All such data is managed by `NotesParser` and stored in the reminder's `notes` field using a single `---` separator:

```
User-written notes
---
tags: #tag1 #tag2 #tag3
[ ] Subtask title {uuid}
[x] Completed subtask {uuid}
```

Everything before `---` is user notes; `tags:` line holds space-separated hashtags; `[ ]`/`[x]` lines are subtasks with title before ID. The metadata block is omitted entirely when empty. Tag pattern `#([\p{L}\p{N}_-]+)` supports Unicode (CJK characters). Subtask IDs are 8-char hex strings (4 random bytes via `SecRandomCopyBytes`).

**Shortcuts CLI Dependency**: Creating subtasks via `--parentTitle` routes through the macOS Shortcuts app (`/usr/bin/shortcuts run <name>`). `ShortcutsService` checks if the named shortcut is installed before attempting to run it. This is the only path that requires an external Shortcut to be configured; direct subtask CRUD via `reminders subtasks` uses `NotesParser` only.

**Output Formatting Strategy**: Commands return domain models (Reminder, CalendarEvent, etc.) which are then formatted by `OutputFormatter` implementations. This separation allows easy addition of new output formats without modifying business logic.

### Priority Values

EventKit uses `EKReminderPriority` which maps to integers: `1` = High, `5` = Medium, `9` = Low. Any other non-zero value is displayed as "Priority N". Zero means no priority.

### Date Handling

All dates use `yyyy-MM-dd HH:mm:ss` format (e.g., "2026-03-10 14:00:00"). EventKit uses `DateComponents` internally, so conversion happens in services. The `Date.from(dateTimeString:)` extension handles parsing.

### Error Handling

Custom `EventCLIError` enum provides structured errors:
- `permissionDenied`: EventKit permission issues
- `notFound`: Missing reminders/lists/events
- `invalidInput`: Bad user input
- `eventKitError`: EventKit API failures

All services throw these errors, which are caught at the command level and formatted for CLI output.

## Critical Constraints

- **macOS 14.0+**: Required for EventKit async APIs (`requestFullAccessToReminders()`, `requestFullAccessToEvents()`)
- **EventKit Permissions**: First run triggers system permission dialogs. `PermissionService` handles this.
- **Thread Safety**: All EventKit operations must be in actors due to non-thread-safe `EKEventStore`
- **Notes Field Limitations**: Tags and subtasks share the notes field. Parsing must handle both formats coexisting.

## Testing Without Installation

Run commands directly from build directory:

```bash
# Test read operations (safe)
.build/debug/event reminders list
.build/debug/event reminders lists list
.build/debug/event reminders subtasks list --id <ID>
.build/debug/event calendar list --start "2026-03-07" --end "2026-03-14"

# Test write operations (creates real data)
.build/debug/event reminders create --title "Test" --tags "test,cli"
.build/debug/event reminders update --id <ID> --completed
.build/debug/event reminders delete --id <ID>
```

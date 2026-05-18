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

# Sync CLI
.build/debug/event sync config --apiUrl <URL> --apiToken <TOKEN> --deviceId <ID>
.build/debug/event sync status
.build/debug/event sync push [--type reminders|calendar|lists|all]
.build/debug/event sync pull [--type reminders|calendar|lists|all]

# Worker development (Cloudflare)
cd worker && pnpm install
cd worker && wrangler dev           # local dev
cd worker && wrangler deploy        # deploy
cd worker && pnpm run db:migrate          # local D1 migration
cd worker && pnpm run db:migrate:remote   # remote D1 migration
cd worker && pnpm test                    # worker tests (vitest-pool-workers)
cd worker && pnpm run typecheck           # worker type check
```

## Architecture

Pure Swift CLI for managing Apple Reminders and Calendar via EventKit, with Cloudflare D1 cloud sync.

### Target Structure

| Target | Type | Purpose |
|--------|------|---------|
| `EventModels` | Library | Shared domain models, formatters, sync DTOs, utilities |
| `EventSync` | Library | `D1SyncClient` HTTP client for Cloudflare D1 |
| `EventCommands` | Library | Shared command helpers |
| `event` | Executable | Main CLI (reminders, calendar, sync commands) |
| `event-sync` | Executable | Standalone sync tool |
| `worker/` | TypeScript | Cloudflare Worker API (Hono + D1) |

Dependencies flow inward: Commands -> Services -> EventKit. Both executables require `-parse-as-library` compiler flag (set in Package.swift) for ArgumentParser `@main`.

### Key Architectural Decisions

**Swift Concurrency with Actors**: All services use `actor` for thread-safe EventKit access. EventKit's `EKEventStore` is not thread-safe, so each service maintains its own store instance within an actor.

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

Custom `EventCLIError` enum provides structured errors: `permissionDenied`, `notFound`, `invalidInput`, `eventKitError`. All services throw these; caught at command level for CLI output.

### Sync Architecture

`SyncService` orchestrates push/pull/delete between local EventKit and a Cloudflare D1 backend via `D1SyncClient` (AsyncHTTPClient). Pull order: lists -> reminders -> calendar events (dependency order).

**Config storage**: `~/.config/event-sync/` with exclusive file lock (`.lock`). Files: `config.json` (apiURL/apiToken/deviceId), `cursors.json`, `id-mapping.json` (local<->remote), `state.json`. All files mode `0o600`. API URL must be HTTPS.

**Worker** (`worker/`): Hono framework on Cloudflare Workers with D1 database. Endpoints at `/api/v1/{entity}/{operation}` for push (POST), pull (GET with cursor pagination), delete (DELETE, soft-delete). Pull accepts a `device` query param so a device never pulls back its own writes. Auth via `API_TOKEN` secret (Bearer token). `wrangler.toml` needs actual `database_id`. Schema lives in `worker/migrations/` (numbered files applied via `wrangler d1 migrations apply`); a daily cron trigger purges records soft-deleted over 30 days ago.

## Code Style

Configured via `.swift-format`: 2-space indentation, 100-character line length, file-scoped declaration privacy. Run `swift format --in-place --recursive Sources Package.swift` to format.

## Conventions

- Conventional commits per `.git-agent/config.yml` (scopes: formula, src, wrk, bin, cli, svc, fmt, cmd, ext, util, sync, mod)
- All tests must pass before merging PRs

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

# Test sync (requires configured worker)
.build/debug/event sync status
.build/debug/event sync push --type reminders
.build/debug/event sync pull --type calendar

# Run tests
swift test
swift test --filter eventTests        # single test target
swift test --filter AlarmTests        # single test suite
```

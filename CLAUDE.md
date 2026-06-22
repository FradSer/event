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
.build/debug/event sync                  # full bidirectional sync (pull, then push)
.build/debug/event sync status
.build/debug/event sync config --api-url <URL> --api-token <TOKEN> --device-id <ID>
# Sync also requires an encryption key (same value on every device):
export EVENT_ENCRYPTION_KEY=$(openssl rand -base64 32)   # generate once, persist in shell rc
.build/debug/event sync push [--type reminders|calendar|lists|all]   # one-directional
.build/debug/event sync pull [--type reminders|calendar|lists|all]   # one-directional

# Worker development (Cloudflare) -- run from skills/apple-events/references/worker/
pnpm install
wrangler dev                              # local dev
wrangler deploy                           # deploy
pnpm run db:migrate                       # local D1 migration
pnpm run db:migrate:remote                # remote D1 migration
pnpm test                                 # worker tests (vitest-pool-workers)
pnpm run typecheck                        # worker type check
```

## Architecture

Pure Swift CLI for managing Apple Reminders and Calendar via EventKit, with end-to-end
encrypted Cloudflare D1 cloud sync built on the shared `AppleSyncKit` package.

### Target Structure

| Target | Type | Purpose |
|--------|------|---------|
| `EventModels` | Library | Shared domain models, formatters, sync DTOs, utilities |
| `EventSync` | Library | Sync orchestration, encryption (`EventEncryptor`), SQLite/Cloudflare backends |
| `EventCommands` | Library | Shared command helpers |
| `event` | Executable | The CLI (reminders, calendar, sync commands) |
| `skills/apple-events/references/worker/` | TypeScript | Cloudflare Worker API (Hono + D1) |

Dependencies flow inward: Commands -> Services -> EventKit. The `event` executable requires the `-parse-as-library` compiler flag (set in Package.swift) for ArgumentParser `@main`.

**AppleSyncKit**: Sync primitives — `D1SyncClient`, `SyncEngine` (snapshot strategy), `ConfigStore`, `EncryptionService` — live in the sibling local package `../apple-sync-kit` (`AppleSyncKit` product), referenced via `.package(path:)`. Swift tools 6.2, language mode `.v6`.

### Key Architectural Decisions

**Swift Concurrency with Actors**: All services use `actor` for thread-safe EventKit access. EventKit's `EKEventStore` is not thread-safe, so each service maintains its own store instance within an actor.

**Advanced Fields via Shortcut**: EventKit exposes no public API for tags, flagged status, URL, or subtask relationships. These fields are handled by the `AdvancedReminderEdit` macOS Shortcut, invoked through `ShortcutsService` (`/usr/bin/shortcuts run <name>`). `ReminderService` post-processes a reminder with the Shortcut only when one of these advanced fields is requested (`tags`, `flagged`, `url`, `parentTitle`); plain reminders never touch Shortcuts. `ShortcutsService` verifies the Shortcut is installed first. The global `--no-shortcuts` flag — or an uninstalled Shortcut — makes these fields degrade gracefully: the basic reminder is still created and a note is printed that advanced fields were skipped. The reminder `notes` field holds only plain user notes (no metadata block).

**Output Formatting Strategy**: Commands return domain models (Reminder, CalendarEvent, etc.) which are then formatted by `OutputFormatter` implementations. This separation allows easy addition of new output formats without modifying business logic.

### Priority Values

EventKit uses `EKReminderPriority` which maps to integers: `1` = High, `5` = Medium, `9` = Low. Any other non-zero value is displayed as "Priority N". Zero means no priority.

### Date Handling

All dates use `yyyy-MM-dd HH:mm:ss` format (e.g., "2026-03-10 14:00:00"). EventKit uses `DateComponents` internally, so conversion happens in services. The `Date.from(dateTimeString:)` extension handles parsing.

### Error Handling

Custom `EventCLIError` enum provides structured errors: `permissionDenied`, `notFound`, `invalidInput`, `eventKitError`. All services throw these; caught at command level for CLI output.

### Sync Architecture

`SyncService` (macOS) and `LinuxSyncService` orchestrate push/pull/delete, delegating the algorithm to `AppleSyncKit.SyncEngine` (`pushSnapshot`/`pushLocalOnly`/`pull`) over `D1SyncClient`. Pull order: lists -> reminders -> calendar events (dependency order). Bare `event sync` is `SyncCommands.FullSync` (the `defaultSubcommand`): a full sync that pulls then pushes; `push`/`pull` remain as one-directional subcommands.

**Encryption (mandatory)**: Reminders and calendar events are end-to-end encrypted; lists are not (no sensitive data). `EventEncryptor.fromEnvironment()` builds an AES-GCM encryptor from `EVENT_ENCRYPTION_KEY` (base64-encoded 32-byte key; generate with `openssl rand -base64 32`, identical on every device). On push, sensitive fields (notes, URL, location, alarms, recurrence, attendees) are sealed into an `EncryptedCarrier` (`{p: ciphertext, i: iv}`) stored in the `notes` field; title/list/dates stay plaintext for search. On pull they are decrypted back. Local EventKit/SQLite always holds plaintext; the Worker's `data` column stores the ciphertext blob. Push/pull of reminders/events throws if the key is unset. The same key is required by the `event sync reminders/calendar` direct-D1 commands.

**Config storage**: `SyncConfigStore.load()` reads connection settings from environment variables first (`EVENT_SYNC_API_URL`, `EVENT_SYNC_API_TOKEN`, optional `EVENT_SYNC_DEVICE_ID` which defaults to the hostname), falling back to `~/.config/event-sync/config.json` (written by `event sync config`). Setting exactly one of the two required env vars is an error. Sync state always lives in `~/.config/event-sync/` with an exclusive file lock (`.lock`): `cursors.json`, `id-mapping.json` (local<->remote), `state.json` — all mode `0o600`. API URL must be HTTPS.

**Worker** (`skills/apple-events/references/worker/`): Hono framework on Cloudflare Workers with D1 database. Endpoints at `/api/v1/{entity}/{operation}` for push (POST), pull (GET with cursor pagination), delete (DELETE, soft-delete). Pull accepts a `device` query param so a device never pulls back its own writes. Auth via `API_TOKEN` secret (Bearer token). `wrangler.toml` needs actual `database_id`. Schema lives in `skills/apple-events/references/worker/migrations/` (numbered files applied via `wrangler d1 migrations apply`); a daily cron trigger purges records soft-deleted over 30 days ago. The Worker is bundled inside the `apple-events` skill so it ships with `npx skills add`.

## Code Style

Configured via `.swift-format`: 2-space indentation, 100-character line length, file-scoped declaration privacy. Run `swift format --in-place --recursive Sources Package.swift` to format.

## Conventions

- Conventional commits per `.git-agent/config.yml` (scopes: app, fm)
- All tests must pass before merging PRs

## Critical Constraints

- **macOS 14.0+**: Required for EventKit async APIs (`requestFullAccessToReminders()`, `requestFullAccessToEvents()`)
- **Encryption key**: `event sync` (and direct-D1 commands) require `EVENT_ENCRYPTION_KEY` (base64 32-byte) for reminders/events; missing key throws on push/pull. Must match across devices.
- **Swift 6.2 / language mode v6**: full Swift 6 concurrency is enforced; `AppleSyncKit` comes from `../apple-sync-kit` (sibling path dependency).
- **EventKit Permissions**: First run triggers system permission dialogs. `PermissionService` handles this.
- **Thread Safety**: All EventKit operations must be in actors due to non-thread-safe `EKEventStore`
- **Advanced Fields**: Tags, flagged, URL, and subtask relationships require the `AdvancedReminderEdit` Shortcut; without it (or with `--no-shortcuts`) these fields are skipped with a printed note.

## Testing Without Installation

Run commands directly from build directory:

```bash
# Test read operations (safe)
.build/debug/event reminders list
.build/debug/event reminders lists list
.build/debug/event calendar list --start "2026-03-07" --end "2026-03-14"

# Test write operations (creates real data)
.build/debug/event reminders create --title "Test" --tags "test,cli"
.build/debug/event reminders update --id <ID> --completed
.build/debug/event reminders delete --id <ID>

# Test sync (requires configured worker)
.build/debug/event sync status
.build/debug/event sync                       # full bidirectional sync
.build/debug/event sync push --type reminders
.build/debug/event sync pull --type calendar

# Run tests
swift test
swift test --filter eventTests        # single test target
swift test --filter AlarmTests        # single test suite
```

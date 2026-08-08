# Changelog

## [0.6.0] - 2026-08-08

### Added
- Support per-event timezones (app)
- Add alarm support to calendar create and update (app)
- Add fail-fast guard for alarm flags (app)
- Add sync daemon subcommand with background state tracking (sync)
- Support legacy ISO 8601 dates (mod)

### Changed
- Standardize calendar timezone sync logic
- Add datetime conversion utility (mod)
- Preserve EventKit timezone
- Clarify reminder sync and completion documentation (skl)
- Document reminder continuation workflow (skl)

### Fixed
- **Permission prompts no longer hang headless.** When no GUI session exists
  (SSH, launchd daemon/agent), the TCC prompt can never be rendered and
  `requestFullAccess*` never returns, blocking callers (e.g. the MCP server)
  forever. `event` now fails fast with a permission error when no GUI session
  is available, and gives up on an unanswerable prompt after 15 s
  (`EVENT_PERMISSION_TIMEOUT_MS`, milliseconds) with a domain-typed
  `Permission denied: Timed out waiting for ...` error. Fixes the Swift side
  of FradSer/mcp-server-apple-events#113.
- Gracefully fall back when convertDateTime fails on timezone-only update (mod)
- Drop synced timezone for all-day events on pull (app)
- Preserve timezones during sync pull (app)
- Validate dates in input timezone (mod)
- Harden alarm offsets to avoid Int overflow and dedupe

## [0.4.0] - 2026-06-23

### Changed
- Extract the sync infrastructure into the shared AppleSyncKit package (encryption, D1 client, sync engine, SQLite store, config store) and depend on it as a versioned remote package
- Upgrade the Linux release Docker image to Swift 6.2

### Fixed
- Decode sync state files that predate the `dateRangeByRemoteId` field (via AppleSyncKit)
- Percent-encode `/` in record ids on delete so slash-bearing ids resolve the Worker route (via AppleSyncKit)

## [0.3.0] - 2026-06-02

### Added
- Cross-platform sync support for Linux via Cloudflare D1 SQLite
- Location-based reminders with search functionality
- Cloud sync with monotonic cursors for improved integrity
- Env-based sync configuration (EVENT_SYNC_API_URL, EVENT_SYNC_API_TOKEN, EVENT_SYNC_DEVICE_ID)
- EventSync library for HTTP client and sync state management
- Apple-events skill with integrated cloud sync
- Worker tests and migrations for Cloudflare D1
- Sync state persistence and conflict detection
- Multi-platform release builds (arm64, x86_64)

### Changed
- Make completed flag optional boolean in reminders
- Migrate Linux sync to sqlite.swift
- Refactor sync commands to unified interface (pull, push, full sync)
- Upgrade worker dependencies (Hono)
- Upgrade Linux Docker image to Swift 6.0
- ISO8601 date format for API and storage (from custom format)

### Fixed
- Sanitize shortcut service output
- Handle corrupt JSON in sync pulls
- Prevent dictionary duplicate key crashes using uniquingKeysWith
- Increase HTTP client timeout to 120s for slow networks
- Deduplicate items in SyncService
- Parse multi-pipe cursor identifiers
- Resolve compile errors in calendar event span
- Include calendar title in event ID calculation
- URL encoding in D1SyncClient delete operations

### Documentation
- Update cloud sync sequence cursor documentation
- Add deployment upgrade instructions
- Document cross-platform support
- Update apple-events skill documentation
- Add sync architecture and design documentation
- Refine Cloudflare sync design


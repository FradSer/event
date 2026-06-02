# Changelog

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


-- Migration 0001: initial schema
-- Applied tracking is handled by Wrangler's d1_migrations table.

CREATE TABLE IF NOT EXISTS reminders (
    id TEXT PRIMARY KEY,
    data TEXT NOT NULL,
    last_modified TEXT NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    source_device TEXT
);

CREATE TABLE IF NOT EXISTS calendar_events (
    id TEXT PRIMARY KEY,
    data TEXT NOT NULL,
    last_modified TEXT NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    source_device TEXT
);

CREATE TABLE IF NOT EXISTS reminder_lists (
    id TEXT PRIMARY KEY,
    data TEXT NOT NULL,
    last_modified TEXT NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    source_device TEXT
);

CREATE INDEX IF NOT EXISTS idx_reminders_updated ON reminders (updated_at, id);
CREATE INDEX IF NOT EXISTS idx_calendar_events_updated ON calendar_events (updated_at, id);
CREATE INDEX IF NOT EXISTS idx_reminder_lists_updated ON reminder_lists (updated_at, id);

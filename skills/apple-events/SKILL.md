---
name: apple-events
description: Use this skill whenever the user wants to manage their Apple Reminders or Calendars using the `event` CLI tool. It covers creating, viewing, searching, updating, and deleting reminders and calendar events, and syncing them to a Cloudflare backend. Works on macOS (via EventKit) and on Linux (via a local SQLite database synced from the Cloudflare backend).
---

# Apple Reminders and Calendar CLI (`event`)

Use the `event` CLI to manage Apple Reminders and Calendars directly from the terminal. You can create, view, search, update, and delete reminders and calendar events, and sync data across devices.

## Setup & Constraints

`event` runs on macOS and Linux, with platform-specific storage backends. All reminder/calendar/list commands below behave identically on both; only the underlying store differs.

- **macOS** — reads and writes Apple Reminders and Calendar directly via EventKit.
  - Requires Reminders.app and Calendar.app to be accessible.
  - If prompted, the user must grant Full Access permissions in System Settings > Privacy & Security > Reminders / Calendars.
  - Some advanced reminder fields (`tags`, `flagged`, `url`, `parentTitle`) require the `AdvancedReminderEdit` Shortcut to be installed (https://www.icloud.com/shortcuts/b578334075754da9ba6e50b501515808). Without it — or with the global `--no-shortcuts` flag — the basic reminder is still created and those fields are skipped with a printed note.
- **Linux** (and other non-Apple platforms) — there is no EventKit, so `event` reads and writes a local SQLite database at `~/.local/share/event-sync/local.db`. Run `event sync` first to populate it from the Cloudflare D1 backend (see [Cloud Sync](#cloud-sync)), then use the same commands to manage that local data. Advanced fields and the `AdvancedReminderEdit` Shortcut are macOS-only.

## Claude Desktop (MCP server)

Claude Desktop has no Bash tool, so it cannot call `event` directly. Use the local
stdio MCP server in `mcp-server/` instead: run `pnpm install` then `pnpm build` inside
`mcp-server/`, then add it to `~/Library/Application Support/Claude/claude_desktop_config.json`.
Claude Desktop's launched `node` process may not inherit `/usr/local/bin`, so make sure
`event` is on its PATH or set the `EVENT_BIN` env var to the binary's full path:

    {
      "mcpServers": {
        "event": {
          "command": "node",
          "args": ["/absolute/path/to/apple-events-cli/mcp-server/dist/index.js"]
        }
      }
    }

Restart Claude Desktop. It exposes three tools: `reminders_tasks`, `reminders_lists`,
`calendar_events` — same underlying CLI, same Shortcuts-based tag convention, local-only
(stdio transport, no network exposure, no OAuth). It does not work from claude.ai Web.

## General Usage

All commands support the `--json` flag to output results in JSON format, which is easier to parse.

## Reminders Management

### List & Search Reminders
- List all incomplete reminders: `event reminders list`
- List including completed: `event reminders list --completed`
- Filter by specific list: `event reminders list --list "List Name"`
- Search by keyword in title and notes: `event reminders search --keyword "groceries"` (also accepts `--list` and `--completed`)

### Create Reminders
- Basic: `event reminders create --title "Buy groceries"`
- With details: `event reminders create --title "Project meeting" --list "Work" --due "2026-03-10 14:00:00" --priority 1 --notes "Discuss Q3 goals"`
- With multiline notes: `event reminders create --title "Shopping list" --notes $'Milk\nBread\nEggs'` (use `$'...'` with `\n` for newlines in bash/zsh)
- Advanced fields (require Shortcut): `event reminders create --title "Urgent bug" --tags "bug,urgent" --flagged true --url "https://github.com/issues/1"`
- Location trigger: `event reminders create --title "Pick up keys" --location "Home" --latitude 37.3349 --longitude -122.0090 --proximity enter` (`--radius` defaults to 100 meters; `--proximity` is `enter` or `leave`)
- With a URL: `event reminders create --title "Fix login bug" --url "https://example.com/issues/42"`. When a task is associated with an external link, always pass it via `--url` — never put URLs in `--notes` as a substitute. If the Shortcut isn't installed, `--url` is skipped gracefully with a printed note.

### Update Reminders
- Mark as completed: `event reminders update --id <UUID> --completed`
- Change title and priority: `event reminders update --id <UUID> --title "New Title" --priority 5`
- Add/remove flag (requires Shortcut): `event reminders update --id <UUID> --flagged true` or `--flagged false`
- Clear a date: `event reminders update --id <UUID> --clear-due` (or `--clear-start`)
- Remove location alarms: `event reminders update --id <UUID> --clear-location`

### Delete Reminders
- Delete by ID: `event reminders delete --id <UUID>`

### List Management
- List all reminder lists: `event reminders lists list`
- Create a list: `event reminders lists create --name "New List Name"`
- Rename a list: `event reminders lists update --id <LIST-ID> --name "New Name"`
- Delete a list: `event reminders lists delete --id <LIST-ID>`

### Subtasks
- There is no dedicated `subtasks` subcommand. Create a subtask by giving a parent's title (requires the Shortcut): `event reminders create --title "Subtask" --parent-title "Parent Task Title"`
- Convert an existing reminder into a subtask: `event reminders update --id <UUID> --parent-title "Parent Task Title"`

## Calendar Management

### List Events
- List upcoming events (default 7 days): `event calendar list`
- List for a date range: `event calendar list --start "2026-03-01" --end "2026-03-31"`
- Filter by calendar: `event calendar list --calendar "Work"`

### Create Events
- Timed event: `event calendar create --title "Standup" --start "2026-03-10 09:00:00" --end "2026-03-10 09:30:00" --calendar "Work" --location "Office" --notes "Daily sync"`
- With multiline notes: `event calendar create --title "Conference" --start "2026-03-10 09:00:00" --end "2026-03-10 17:00:00" --notes $'Agenda:\nKeynote\nWorkshop\nBreakout sessions'`
- All-day event: use `yyyy-MM-dd` for `--start` / `--end`.

### Update & Delete Events
- Update: `event calendar update --id <ID> --title "New Title" --start "2026-03-10 10:00:00" --end "2026-03-10 11:00:00"`
- Delete: `event calendar delete --id <ID>` (for recurring events, `--span` controls scope)

## Cloud Sync

Sync reminders, calendar events, and lists across devices through a Cloudflare D1 backend.

- Run a full bidirectional sync (pull, then push): `event sync`
- Check configuration and sync state: `event sync status`
- Advanced one-directional sync: `event sync push` / `event sync pull` (both accept `--type reminders|calendar|lists|all`)

On macOS, sync bridges EventKit and D1. On Linux, sync bridges the local SQLite database and D1 — so on a fresh Linux machine, `event sync` (or `event sync pull`) is the first step before any data is available to the other commands.

Sync requires a configured Cloudflare D1 backend: set the `EVENT_SYNC_API_URL` and `EVENT_SYNC_API_TOKEN` environment variables (the device id defaults to the hostname). For one-time Worker deployment and per-device environment setup, see [`references/cloud-sync.md`](references/cloud-sync.md); the Worker source is bundled with this skill at `references/worker/`.

## Limitations & Notes

- **Dates**: timed values use `yyyy-MM-dd HH:mm:ss` (e.g. "2026-03-10 14:00:00"); all-day calendar events use `yyyy-MM-dd`.
- **Priority**: 1 = High, 5 = Medium, 9 = Low, 0 = None.
- **Advanced fields**: `tags`, `flagged`, `url`, and subtask relationships (`parentTitle`) are handled via the `AdvancedReminderEdit` Shortcut. Without it (or with `--no-shortcuts`) they are skipped. The reminder `notes` field holds plain user notes only — no metadata block.
- **Notes formatting**: newlines in `--notes` are preserved as plain text line breaks; markdown syntax (bold, italic, lists, etc.) is not interpreted and will appear literally. Bullet characters (`•`) must be written as `-` instead.
- **Calendar sync window**: only events from one year in the past to two years ahead are pushed and pulled. Events moved outside this window remain in the cloud until explicitly deleted locally.
- **Sync conflicts**: timed entities use last-write-wins using modification timestamps (falling back to creation time). Local copies without any timestamp are not overwritten on pull.
- **Reminder lists**: no per-list modification timestamp — concurrent renames last-write-wins on pull.
- **Advanced fields on sync**: `tags`, `flagged`, `url`, and subtask relationships are not restored during sync pull; use local Shortcut-backed commands for those fields.

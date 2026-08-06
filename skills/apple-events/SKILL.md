---
name: apple-events
description: Use this skill whenever the user wants to manage their Apple Reminders or Calendars using the `event` CLI tool. It covers creating, viewing, searching, updating, and deleting reminders and calendar events, and syncing them to a Cloudflare backend. Works on macOS (via EventKit) and on Linux (via a local SQLite database synced from the Cloudflare backend).
argument-hint: "[what to create or look up — empty to capture from context]"
---

# Apple Reminders and Calendar CLI (`event`)

Use the `event` CLI to manage Apple Reminders and Calendars directly from the terminal. You can create, view, search, update, and delete reminders and calendar events, and sync data across devices.

## Invocation & Arguments

Treat `$ARGUMENTS` as a free-form natural-language instruction and map it to the appropriate `event` command(s) documented below. Resolve relative dates and times ("tomorrow", "next Monday", "in 2 hours", "this Friday afternoon") against the current date/time before building the command. Examples:

- `/apple-events remind me to call the dentist tomorrow at 3pm` -> `event reminders create ...`
- `/apple-events what's on my calendar this week?` -> `event calendar list ...`
- `/apple-events block 2-4pm Friday for deep work` -> `event calendar create ...`

### When no arguments are given

If `$ARGUMENTS` is empty, do **not** default to listing. Instead, infer intent from the current conversation:

1. **Scan the recent conversation** for an actionable item the user might want captured — a commitment, deadline, follow-up, meeting, appointment, or TODO.
2. **Classify it:**
   - A **task** (something to do, optionally with a due date) -> a reminder (`event reminders create`).
   - A **scheduled event** (something happening at a specific time, with a start/end) -> a calendar event (`event calendar create`).
3. **Confirm with the `AskUserQuestion` tool before creating anything.** Present the inferred type and details (title, date/time, target list/calendar) so the user can confirm, switch task<->event, adjust fields, or decline. Never create in the no-args path without explicit confirmation.
4. If **nothing actionable** is found in the conversation, use `AskUserQuestion` to ask what the user would like to create (task or event) rather than guessing.

## Setup & Constraints

`event` runs on macOS and Linux, with platform-specific storage backends. All reminder/calendar/list commands below behave identically on both; only the underlying store differs.

- **macOS** — reads and writes Apple Reminders and Calendar directly via EventKit.
  - Requires Reminders.app and Calendar.app to be accessible.
  - If prompted, the user must grant Full Access permissions in System Settings > Privacy & Security > Reminders / Calendars.
  - Some advanced reminder fields (`tags`, `flagged`, `url`, `parentTitle`) require the `AdvancedReminderEdit` Shortcut to be installed (https://www.icloud.com/shortcuts/b578334075754da9ba6e50b501515808). Without it — or with the global `--no-shortcuts` flag — the basic reminder is still created and those fields are skipped with a printed note.
- **Linux** (and other non-Apple platforms) — there is no EventKit, so `event` reads and writes a local SQLite database at `~/.local/share/event-sync/local.db`. Run `event sync` first to populate it from the Cloudflare D1 backend (see [Cloud Sync](#cloud-sync)), then use the same commands to manage that local data. Advanced fields and the `AdvancedReminderEdit` Shortcut are macOS-only.

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
- Continuing coding/agent work: when a reminder tracks an in-progress coding or agent task tied to a specific project and Claude Code session, append a continuation command to `--notes` on its own line: `Continue:\ncd <project-dir> && claude -r <session-id>` (use `$'...\n...'` for the newline). Resolve `<session-id>` by finding the Claude Code session whose transcript actually holds the task's context — transcripts live at `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`, so grep them by keyword rather than assuming the current session's id. Don't guess `<project-dir>` or `<session-id>`; confirm with `AskUserQuestion` if either is unclear.

### Update Reminders
- Mark as completed: `event reminders update --id <UUID> --completed true` (or `--completed false` to uncheck)
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
- List upcoming events (default 1 month from today): `event calendar list`
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

- Run a full bidirectional sync (pull, then push): `event sync` (equivalently `event sync run`)
- Check configuration and sync state: `event sync status`
- Configure the backend connection: `event sync config --api-url <URL> --api-token <TOKEN> [--device-id <ID>]` (writes `~/.config/event-sync/config.json`; env vars take precedence when set)
- Advanced one-directional sync: `event sync push` / `event sync pull` (both accept `--type reminders|calendar|lists|all`)

On macOS, sync bridges EventKit and D1. On Linux, sync bridges the local SQLite database and D1 — so on a fresh Linux machine, `event sync` (or `event sync pull`) is the first step before any data is available to the other commands.

**What syncs.** Basic fields plus `url`, `location`, `alarms`, `recurrenceRules`, and calendar `attendees` travel in the sync payload and are restored on pull — so they survive a cross-device sync. Tags, flagged status, and subtask relationships (`parentTitle`) are macOS/Shortcut-only and are **not** part of the sync payload; they must be set locally on each device.

**D1-direct subcommands** bypass local storage and read/write the cloud backend directly: `event sync reminders list` / `event sync reminders create`, and `event sync calendar list`. Use these to inspect or seed the cloud store without touching EventKit or the local SQLite DB.

Sync requires a configured Cloudflare D1 backend: set the `EVENT_SYNC_API_URL` and `EVENT_SYNC_API_TOKEN` environment variables (the device id defaults to the hostname). Reminders and calendar events are also end-to-end encrypted, so sync requires `EVENT_ENCRYPTION_KEY` — a base64-encoded 32-byte key (`openssl rand -base64 32`) that must be **identical on every device**; reminder/calendar push and pull fail if it is unset or mismatched (lists are not encrypted). For one-time Worker deployment, key generation, and per-device environment setup, see [`references/cloud-sync.md`](references/cloud-sync.md). The canonical Worker is shared with the `note` CLI: deploy it once serving all five tables (`migrations/all`) and point both CLIs at the same URL and token. The Worker source is not bundled here — `./references/fetch-worker.sh` fetches it on demand into a gitignored `references/worker/`.

## Limitations & Notes

- **Dates**: timed values use `yyyy-MM-dd HH:mm:ss` (e.g. "2026-03-10 14:00:00"); all-day calendar events use `yyyy-MM-dd`.
- **Priority**: 1 = High, 5 = Medium, 9 = Low, 0 = None.
- **Advanced fields**: `tags`, `flagged`, `url`, and subtask relationships (`parentTitle`) are handled via the `AdvancedReminderEdit` Shortcut. Without it (or with `--no-shortcuts`) they are skipped. The reminder `notes` field holds plain user notes only — no metadata block.
- **Notes formatting**: newlines in `--notes` are preserved as plain text line breaks; markdown syntax (bold, italic, lists, etc.) is not interpreted and will appear literally. Bullet characters (`•`) must be written as `-` instead.
- **Calendar sync window**: only events from one year in the past to two years ahead are pushed and pulled. Events moved outside this window remain in the cloud until explicitly deleted locally.
- **Sync conflicts**: timed entities use last-write-wins using modification timestamps (falling back to creation time). Local copies without any timestamp are not overwritten on pull.
- **Reminder lists**: no per-list modification timestamp — concurrent renames last-write-wins on pull.
- **Advanced fields on sync**: `tags`, `flagged`, and subtask relationships (`parentTitle`) are macOS/Shortcut-only and are not synced; use local Shortcut-backed commands for those fields. In contrast, `url`, `location`, `alarms`, `recurrenceRules`, and calendar `attendees` travel in the sync payload and are restored on pull.
- **Encryption**: reminders and calendar events are end-to-end encrypted with AES-GCM before upload; the cloud only ever stores ciphertext for those fields (title, list, and dates stay plaintext for search). This requires `EVENT_ENCRYPTION_KEY` to be set and identical across devices — see [Cloud Sync](#cloud-sync). Lists carry no sensitive data and are not encrypted.

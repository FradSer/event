---
name: apple-events
description: Use this skill whenever the user wants to manage their Apple Reminders or Calendars using the `event` CLI tool. It covers creating, viewing, searching, updating, and deleting reminders and calendar events, and syncing them to a Cloudflare backend.
---

# Apple Reminders and Calendar CLI (`event`)

Use the `event` CLI to manage Apple Reminders and Calendars directly from the terminal. You can create, view, search, update, and delete reminders and calendar events, and sync data across devices.

## Setup & Constraints

- **macOS-only**.
- Requires Reminders.app and Calendar.app to be accessible.
- If prompted, the user must grant Full Access permissions in System Settings > Privacy & Security > Reminders / Calendars.
- Some advanced reminder fields (`tags`, `flagged`, `url`, `parentTitle`) require the `AdvancedReminderEdit` Shortcut to be installed (https://www.icloud.com/shortcuts/b578334075754da9ba6e50b501515808). Without it — or with the global `--no-shortcuts` flag — the basic reminder is still created and those fields are skipped with a printed note.

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
- Advanced fields (require Shortcut): `event reminders create --title "Urgent bug" --tags "bug,urgent" --flagged true --url "https://github.com/issues/1"`
- Location trigger: `event reminders create --title "Pick up keys" --location "Home" --latitude 37.3349 --longitude -122.0090 --proximity enter` (`--radius` defaults to 100 meters; `--proximity` is `enter` or `leave`)

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
- All-day event: use `yyyy-MM-dd` for `--start` / `--end`.

### Update & Delete Events
- Update: `event calendar update --id <ID> --title "New Title" --start "2026-03-10 10:00:00" --end "2026-03-10 11:00:00"`
- Delete: `event calendar delete --id <ID>` (for recurring events, `--span` controls scope)

## Cloud Sync

Sync reminders, calendar events, and lists across devices through a Cloudflare D1 backend.

- Run a full bidirectional sync (pull, then push): `event sync`
- Check configuration and sync state: `event sync status`
- Advanced one-directional sync: `event sync push` / `event sync pull` (both accept `--type reminders|calendar|lists|all`)

Sync requires a configured Cloudflare D1 backend: set the `EVENT_SYNC_API_URL` and `EVENT_SYNC_API_TOKEN` environment variables (the device id defaults to the hostname). For one-time Worker deployment and per-device environment setup, see [`references/cloud-sync.md`](references/cloud-sync.md); the Worker source is bundled with this skill at `references/worker/`.

## Limitations & Notes

- **Dates**: timed values use `yyyy-MM-dd HH:mm:ss` (e.g. "2026-03-10 14:00:00"); all-day calendar events use `yyyy-MM-dd`.
- **Priority**: 1 = High, 5 = Medium, 9 = Low, 0 = None.
- **Advanced fields**: `tags`, `flagged`, `url`, and subtask relationships (`parentTitle`) are handled via the `AdvancedReminderEdit` Shortcut. Without it (or with `--no-shortcuts`) they are skipped. The reminder `notes` field holds plain user notes only — no metadata block.
- **Calendar sync window**: only events from one year in the past to two years ahead are synced.

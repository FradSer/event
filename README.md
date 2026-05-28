# event ![Swift](https://img.shields.io/badge/Swift-5.9+-F05138) ![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Linux-lightgrey)

[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE) [![Twitter Follow](https://img.shields.io/twitter/follow/FradSer?style=social)](https://twitter.com/FradSer)

**English** | [简体中文](README.zh-CN.md)

A pure Swift CLI tool for managing Apple Reminders and Calendar. On macOS it reads and writes Apple data directly through EventKit; on Linux it works against a local SQLite store kept in sync with a Cloudflare D1 backend.

## Features

- Create, read, update, and delete reminders
- Full CRUD for calendar events
- Organize reminders into lists
- Add and manage subtasks within reminders
- Tag reminders for organization
- Markdown (default) and JSON output
- Cloud sync across devices with Cloudflare D1 via `event sync`
- Runs on macOS (EventKit) and Linux (local SQLite + sync)

## Requirements

- Swift 5.9 or later
- **macOS** 14.0 or later — reads and writes Apple Reminders and Calendar directly via EventKit
- **Linux** — no EventKit, so `event` works against a local SQLite database at `~/.local/share/event-sync/local.db`. Run `event sync` to populate it from Cloudflare D1, then use the same commands on that data

## Installation

### Homebrew (Recommended)

```bash
# Add tap
brew tap FradSer/brew

# Install
brew install event
```

### Build from Source

```bash
# Clone the repository
git clone https://github.com/FradSer/event.git
cd event

# Build and install
swift build -c release
cp .build/release/event /usr/local/bin/
```

### First Run - Grant Permissions (macOS)

On first run, the tool requests access to Reminders and Calendar. If the system permission dialog doesn't appear, manually grant access:

**Recommended: Use AdvancedReminderEdit Shortcut**
- Download [AdvancedReminderEdit](https://www.icloud.com/shortcuts/b578334075754da9ba6e50b501515808)
- Open Shortcuts and run the shortcut once
- This enables advanced reminder features: native tags, URL, and parent reminder support
- Also triggers the system permission dialogs for Reminders and Calendar

Alternatively, enable permissions in System Settings:
- System Settings > Privacy & Security > Reminders > Enable Terminal
- System Settings > Privacy & Security > Calendars > Enable Terminal

## Usage

### Reminders

```bash
# List reminders
event reminders list

# Create a reminder
event reminders create --title "Buy groceries"

# Create with tags
event reminders create --title "Buy groceries" --tags "shopping,urgent"

# Mark reminder complete
event reminders update --id <REMINDER_ID> --completed

# Delete a reminder
event reminders delete --id <REMINDER_ID>
```

### Calendar

```bash
# List calendar events
event calendar list

# List events in date range
event calendar list --start "2026-03-01" --end "2026-03-31"

# Create an event
event calendar create --title "Meeting" --start "2026-03-10 14:00:00" --end "2026-03-10 15:00:00"
```

### Lists

```bash
# List all reminder lists
event reminders lists list

# Create a list
event reminders lists create --name "Work"
```

### Sync (Cloudflare D1)

`event sync` keeps reminders, calendar events, and lists in sync across devices
through a Cloudflare Worker backed by D1.

#### 1. Deploy the Worker (one-time)

```bash
cd skills/apple-events/references/worker
pnpm install
pnpm exec wrangler login
cp wrangler.toml.example wrangler.toml    # copy the config template
pnpm exec wrangler d1 create event-sync   # copy the database_id into wrangler.toml
pnpm run db:migrate:remote                # create the D1 tables
openssl rand -hex 32 | pnpm exec wrangler secret put API_TOKEN   # auto-generate and set a strong shared token
pnpm run deploy                           # prints https://<worker>.workers.dev
```

#### 2. Configure each device

Set two environment variables — add them to `~/.zshrc` (or `~/.bashrc`) so they
persist across shells:

```bash
export EVENT_SYNC_API_URL=https://<your-worker>.workers.dev
export EVENT_SYNC_API_TOKEN=<the API_TOKEN from step 1>
# EVENT_SYNC_DEVICE_ID is optional; defaults to the machine hostname

event sync status   # verify the configuration
```

Environment variables take precedence. If they are unset, `event` falls back to
a config file written by `event sync config --api-url <URL> --api-token <TOKEN>`
(`--device-id` is optional and defaults to the machine hostname).

> **Note:** the config file at `~/.config/event-sync/config.json` stores the API
> token in plain text (mode `0600`, owner-only). Do not commit it to version
> control or copy it to shared storage.

#### 3. Sync

```bash
event sync   # full bidirectional sync: pull, then push
```

Run it on each device. The device id (hostname by default) keeps devices
distinct, and a device never pulls back its own writes. On Linux this is the
first step on a fresh machine — it fills the local SQLite store before the other
`event` commands have anything to show.

Advanced one-directional / selective sync:

```bash
event sync push --type all      # push only
event sync pull --type calendar # pull only, one entity type
```

> **Note:** Calendar sync covers events from one year in the past to two years
> ahead; events outside this window are not synced. Conflicts resolve by
> last-write-wins: a pull never overwrites a local copy that was modified more
> recently than the server's version, and that copy is pushed on the next sync.

For more commands, run `event --help`.

## Agent Skill

The [`apple-events`](skills/apple-events/) skill lets AI agents manage your Apple Reminders and Calendar through `event`.

1. Ensure `event` CLI is installed and in your system PATH.
2. Install the skill:
   ```bash
   npx skills add https://github.com/FradSer/event --skill apple-events
   ```

## License

MIT License

## Author

Frad Lee - [frad.me](https://frad.me)

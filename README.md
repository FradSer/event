# event ![Swift](https://img.shields.io/badge/Swift-5.9+-F05138) ![macOS](https://img.shields.io/badge/macOS-14.0+-000000)

[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE) [![Twitter Follow](https://img.shields.io/twitter/follow/FradSer?style=social)](https://twitter.com/FradSer)

**English** | [简体中文](README.zh-CN.md)

A pure Swift CLI tool for managing Apple Reminders and Calendar on macOS.

## Features

- **Reminders**: Create, read, update, and delete reminders
- **Calendar**: Full CRUD operations for calendar events
- **Lists**: Organize reminders into lists
- **Subtasks**: Add and manage subtasks within reminders
- **Tags**: Tag reminders for organization
- **Multiple Formats**: Markdown (default) and JSON output
- **Cloud Sync**: Sync data with Cloudflare D1 via the `event-sync` command

## Requirements

- macOS 14.0 or later
- Swift 5.9 or later

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

### First Run - Grant Permissions

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

```bash
# Configure sync (requires Cloudflare Worker)
event sync config --apiUrl <WORKER_URL> --apiToken <TOKEN> --deviceId <DEVICE_ID>

# Push local data to cloud
event sync push --type all

# Pull data from cloud
event sync pull --type all

# Check sync status
event sync status
```

> **Note:** Calendar sync covers events from one year in the past to two years
> ahead; events outside this window are not synced. Conflicts resolve by
> last-write-wins: a pull never overwrites a local copy that was modified more
> recently than the server's version, and that copy is pushed on the next sync.

For more commands, run `event --help`.

## Agent Skill

The `apple-events` skill lives in the [`FradSer/skills`](https://github.com/FradSer/skills) repository and lets AI agents manage your Apple Reminders and Calendar through `event`.

1. Ensure `event` CLI is installed and in your system PATH.
2. Install the skill:
   ```bash
   npx skills add https://github.com/FradSer/skills --skill apple-events
   ```

## License

MIT License

## Author

Frad Lee - [frad.me](https://frad.me)

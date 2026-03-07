# event

A pure Swift CLI tool for managing Apple Reminders and Calendar on macOS.

[中文版](./README.zh-CN.md)

## Features

- Reminders Management: Create, read, update, and delete reminders
- Calendar Events: Manage calendar events with full CRUD operations
- Lists: Organize reminders into lists
- Subtasks: Add and manage subtasks within reminders
- Tags: Tag reminders for better organization
- Multiple Output Formats: Markdown (default) and JSON

## Requirements

- macOS 14.0 or later
- Swift 5.9 or later

## Installation

### Homebrew (Recommended)

```bash
# Add tap
brew tap FradSer/event

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

On first run, the tool will request access to Reminders and Calendar. If the system permission dialog doesn't appear, you can manually grant access:

**Recommended: Use AdvancedReminderEdit Shortcut**
- Download [AdvancedReminderEdit](https://www.icloud.com/shortcuts/b578334075754da9ba6e50b501515808)
- Open the Shortcuts app and run the shortcut once
- This enables advanced reminder features: native tags, URL, and parent reminder support
- It also triggers the system permission dialogs for Reminders and Calendar

Alternatively, you can manually enable permissions in System Settings:
- System Settings > Privacy & Security > Reminders > Enable Terminal (or your shell)
- System Settings > Privacy & Security > Calendars > Enable Terminal

## Usage

```bash
# List reminders
event reminders list

# Create a reminder
event reminders create --title "Buy groceries"

# List calendar events
event calendar list

# Create an event
event calendar create --title "Meeting" --start "2026-03-10 14:00:00" --end "2026-03-10 15:00:00"
```

For more commands, run `event --help`

## License

MIT License

## Author

Frad Lee - https://frad.me

# event

A pure Swift CLI tool for managing Apple Reminders and Calendar on macOS.

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

```bash
# Clone the repository
git clone https://github.com/fradser/event.git
cd event

# Build and install
swift build -c release
cp .build/release/event /usr/local/bin/
```

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

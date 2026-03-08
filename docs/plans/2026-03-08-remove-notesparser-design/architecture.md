# Design Document: Remove NotesParser

## 1. Overview

This design document describes the architecture and implementation details for removing the `NotesParser` component from the codebase. The change migrates tag, flagged status, and URL handling from a notes-field-based solution to a Shortcut-based approach, leveraging the macOS Shortcuts CLI for advanced reminder features that EventKit does not natively support.

## 2. Problem Statement

EventKit (Apple's framework for Calendar and Reminders) does not natively support several reminder properties:

- **Tags**: No native tag support in EKReminder
- **Flagged Status**: No flagged property in EKReminder
- **Subtasks**: No subtask/child-task relationship support
- **URL**: Supported via `url` property, but inconsistent in practice

The previous implementation used a " NotesParser" to serialize these properties into the reminder's `notes` field, creating a hybrid storage solution that mixed user notes with metadata.

## 3. Architecture

### 3.1 Layer Architecture

```
Commands → Services → EventKit
     ↓
  Models/Formatters (cross-cutting)
```

### 3.2 Data Flow

```
User Input
    │
    ▼
ReminderCommands (parse arguments)
    │
    ▼
ReminderService
    │
    ├─► createViaEventKit() ──► EKReminder
    │
    └─► postProcessReminder() ──► ShortcutsService ──► AdvancedReminderEdit Shortcut
```

### 3.3 Component Responsibilities

| Component | Responsibility |
|-----------|----------------|
| `ReminderCommands` | Parse CLI arguments, handle `--no-shortcuts` flag |
| `ReminderService` | Core reminder CRUD, coordinates EventKit and Shortcut |
| `ShortcutsService` | Execute macOS Shortcuts, check installation |
| `PermissionService` | Request and verify EventKit permissions |

## 4. Detailed Design

### 4.1 Reminder Operations

#### Create Reminder Flow
1. Validate permissions
2. Create EKReminder via EventKit with basic fields
3. If `useShortcuts && (tags || parentTitle || flagged)`:
   - Check if shortcut is installed
   - If installed: execute shortcut with payload
   - If not installed: print info message
4. Fetch and return final reminder state

#### Update Reminder Flow
1. Validate permissions
2. Update EKReminder via EventKit
3. Same post-processing as create

### 4.2 Shortcut Integration

#### Payload Structure
```swift
struct AdvancedReminderEditPayload: Encodable {
    let title: String
    let list: String?
    let tags: String?
    let url: String?
    let parentTitle: String?
    let isFlagged: String?
}
```

#### Execution
1. Check installation: `shortcuts list`
2. Execute: `shortcuts run <name>` with JSON via stdin
3. Handle errors gracefully

### 4.3 Field Mapping

| User Input | EventKit | Shortcut |
|------------|----------|----------|
| `--title` | EKReminder.title | payload.title |
| `--notes` | EKReminder.notes | - |
| `--url` | EKReminder.url | payload.url |
| `--due` | EKReminder.dueDateComponents | - |
| `--priority` | EKReminder.priority | - |
| `--completed` | EKReminder.isCompleted | - |
| `--tags` | - | payload.tags |
| `--flagged` | - | payload.isFlagged |
| `--parent-title` | - | payload.parentTitle |

### 4.4 Global Flag Behavior

| Flag | Behavior |
|------|----------|
| (none) | Shortcuts enabled |
| `--no-shortcuts` | Disable all Shortcut calls |

## 5. Error Handling

| Error Type | Handling |
|------------|----------|
| Permission Denied | Throw error, guide to System Preferences |
| Reminder Not Found | Throw error with ID |
| Shortcut Not Installed | Print info message, continue |
| Shortcut Failed | Print warning, continue |

### User Messages
```
Note: AdvancedReminderEdit shortcut not found.
Install it at: https://www.icloud.com/shortcuts/b578334075754da9ba6e50b501515808
Without it, only basic reminder fields can be set.
```

## 6. Testing Strategy

### Unit Tests
- ReminderService: Create/update flows
- ShortcutsService: Installation check, execution
- Reminder Model: Initialization from EKReminder

### Integration Tests
- Create with tags (shortcut installed/not installed)
- Create with --no-shortcuts

## 7. Deleted Components

| File | Reason |
|------|--------|
| `NotesParser.swift` | Replaced by Shortcut |
| `SubtaskService.swift` | Subtasks not supported |
| `SubtaskCommands.swift` | Subtask commands removed |
| `Subtask.swift` | Model removed |

## 8. Backward Compatibility

### Breaking Changes
1. Notes field format: Old reminders won't show tags
2. Subtask commands: `reminders subtasks` removed

### Migration Path
1. Install AdvancedReminderEdit Shortcut
2. Recreate tags using `--tags`
3. Use `--parent-title` for relationships

## 9. Security

- Only predefined shortcut names executed
- Input validated before passing to external commands
- No arbitrary command execution

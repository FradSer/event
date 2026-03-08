# Best Practices: Remove NotesParser Implementation

## 1. Code Organization

### Layer Separation

```
Commands → Services → EventKit
     ↓
  Models/Formatters
```

- **Commands**: Argument parsing only
- **Services**: Business logic
- **Models**: Pure data structures

### Actor Usage

All EventKit services must use `actor`:

```swift
actor ReminderService {
    private let eventStore = EKEventStore()
}
```

**Reason**: EKEventStore is not thread-safe.

## 2. Shortcut Integration

### Check Installation First

```swift
let isInstalled = try await shortcutsService.isShortcutInstalled(name: shortcutName)
if isInstalled {
    // Execute
}
```

### Graceful Degradation

Never fail if shortcut is unavailable:

```swift
// GOOD: Inform user, continue
if !isShortcutInstalled {
    print("Note: Shortcut not found.")
    return
}
```

### Clear Error Messages

```swift
print("Install it at: https://www.icloud.com/shortcuts/...")
```

## 3. CLI Flag Design

### Inverted Flags

```swift
@Flag(name: .shortAndLong, help: "Disable Shortcut integration")
var noShortcuts: Bool = false
```

Usage: `--no-shortcuts` or `-n`

## 4. Error Handling

### Typed Errors

```swift
enum EventCLIError: Error {
    case permissionDenied
    case notFound(String)
    case invalidInput(String)
    case eventKitError(String)
}
```

### Fail Fast vs Graceful

| Feature | Behavior |
|---------|----------|
| EventKit access | Throw error |
| Shortcut | Print warning, continue |

## 5. Testing

- Unit test service logic
- Test shortcut fallback
- Keep tests independent

## 6. Security

- Validate input before external commands
- Only predefined shortcut names

```swift
// GOOD
let shortcutName = "AdvancedReminderEdit"
```

## 7. Performance

### Lazy Service Initialization

```swift
func run() async throws {
    let service = ReminderService()
}
```

### Batch Operations

```swift
// GOOD: Single save
ekReminder.title = "New"
ekReminder.notes = "Notes"
try eventStore.save(ekReminder, commit: true)
```

## 8. Migration

Provide clear migration path:

```markdown
### Migration from NotesParser

1. Install the Shortcut
2. Recreate tags using: event reminders update --id <ID> --tags "new,tags"
```

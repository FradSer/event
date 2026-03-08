# Task 005: Update ReminderService Shortcut Flow

## Overview
Update ReminderService to use Shortcut for tags/flagged/url, with graceful fallback when Shortcut is unavailable.

## BDD Scenario

```gherkin
Scenario: Create reminder with tags (shortcut available)
  Given AdvancedReminderEdit shortcut is installed
  When user runs "reminders create --title 'Test' --tags 'work'"
  Then title is saved via EventKit
  And tags are set via Shortcut

Scenario: Create reminder with tags (shortcut NOT available)
  Given AdvancedReminderEdit shortcut is NOT installed
  When user runs "reminders create --title 'Test' --tags 'work'"
  Then title is saved via EventKit
  And tags are silently skipped
  And user sees info message about tags not being set

Scenario: Create reminder with --no-shortcuts
  Given --no-shortcuts flag is used
  When user runs "reminders create --title 'Test' --tags 'work' --flagged"
  Then only EventKit fields are saved
  And tags/flagged are silently skipped

Scenario: Update reminder with flagged (shortcut available)
  Given AdvancedReminderEdit shortcut is installed
  When user runs "reminders update --id XXX --flagged"
  Then flagged status is set via Shortcut

Scenario: Update reminder with flagged (shortcut NOT available)
  Given AdvancedReminderEdit shortcut is NOT installed
  When user runs "reminders update --id XXX --flagged"
  Then flagged status is silently skipped

Scenario: Create reminder with parentTitle (shortcut available)
  Given AdvancedReminderEdit shortcut is installed
  When user runs "reminders create --title 'Child' --parentTitle 'Parent'"
  Then parentTitle is set via Shortcut (creates subtask relationship)

Scenario: Create reminder with parentTitle (shortcut NOT available)
  Given AdvancedReminderEdit shortcut is NOT installed
  When user runs "reminders create --title 'Child' --parentTitle 'Parent'"
  Then reminder is created but no parent relationship is set
  And user sees info message

## Files
- Modify: `Sources/event/Services/ReminderService.swift`

## Changes Required

1. Remove all NotesParser references in ReminderService
2. Update create flow:
   - Create reminder via EventKit
   - If tags/url/flagged/parentTitle provided, try Shortcut
   - If Shortcut unavailable, silently skip with info message
3. Update update flow:
   - Update EventKit fields
   - If tags/url/flagged/parentTitle provided, try Shortcut
   - If Shortcut unavailable, silently skip
4. Add --no-shortcuts check before calling ShortcutsService
5. Remove fallbackProcessing() that used NotesParser

## Implementation Logic

```swift
// Pseudo-code
func createReminder(..., tags: String?, flagged: Bool?, url: String?, parentTitle: String?, useShortcuts: Bool) async throws {
    // 1. Create basic reminder via EventKit
    let reminderId = try createViaEventKit(...)

    // 2. Advanced fields via Shortcut (if requested and shortcuts enabled)
    if useShortcuts && (tags != nil || flagged != nil || url != nil || parentTitle != nil) {
        if let shortcut = try? await shortcutsService.runShortcut(...) {
            // Success
        } else {
            print("Note: Advanced fields (tags/flagged/url) require AdvancedReminderEdit shortcut")
        }
    }

    return try fetchReminder(id: reminderId)
}
```

## Verification
```bash
# Build and test
swift build

# Test with shortcut (if installed)
.build/debug/event reminders create --title "Test" --tags "work" --flagged

# Test without shortcut - should show info message
# (requires removing or breaking the shortcut)
```

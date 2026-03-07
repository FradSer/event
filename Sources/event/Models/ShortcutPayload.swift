import Foundation

// MARK: - Shortcut Payload

/// Payload for creating a reminder via the CreateAdvancedReminder shortcut
struct ShortcutReminderPayload: Encodable {
    let title: String
    let listName: String?
    let notes: String?
    let tags: [String]?
    let subtasks: [String]?
}

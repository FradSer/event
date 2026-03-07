import Foundation

// MARK: - Shortcut Payload

/// Payload for creating a reminder via the CreateAdvancedReminder shortcut
struct ShortcutReminderPayload: Encodable {
    let title: String
    let listName: String?
    let notes: String?
    let url: String?
    let tags: String? // Changed to String to make it easier to parse in Shortcuts
    let parentTitle: String? // Changed from parentId because Shortcuts can't search by ID reliably
}

/// Payload for editing a reminder via the AdvancedReminderEdit shortcut
struct AdvancedReminderEditPayload: Encodable {
    let title: String            // Reminder title to find (Shortcuts can't search by ID)
    let list: String?            // List name to narrow search scope
    let tags: String?            // Comma-separated tags (e.g., "work,urgent")
    let url: String?             // URL to set
    let parentTitle: String?     // Parent reminder title for creating subtask relationship

    enum CodingKeys: String, CodingKey {
        case title
        case list
        case tags
        case url
        case parentTitle
    }
}

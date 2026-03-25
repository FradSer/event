import Foundation

// MARK: - Shortcut Payload

/// Payload for creating a reminder via the CreateAdvancedReminder shortcut
public struct ShortcutReminderPayload: Encodable, Sendable {
    public let title: String
    public let listName: String?
    public let notes: String?
    public let url: String?
    public let tags: String?  // Changed to String to make it easier to parse in Shortcuts
    public let parentTitle: String?  // Changed from parentId because Shortcuts can't search by ID reliably

    public init(
        title: String,
        listName: String?,
        notes: String?,
        url: String?,
        tags: String?,
        parentTitle: String?
    ) {
        self.title = title
        self.listName = listName
        self.notes = notes
        self.url = url
        self.tags = tags
        self.parentTitle = parentTitle
    }
}

/// Payload for editing a reminder via the AdvancedReminderEdit shortcut
public struct AdvancedReminderEditPayload: Encodable, Sendable {
    public let title: String  // Reminder title to find (Shortcuts can't search by ID)
    public let list: String?  // List name to narrow search scope
    public let tags: String?  // Comma-separated tags (e.g., "work,urgent")
    public let url: String?  // URL to set
    public let parentTitle: String?  // Parent reminder title for creating subtask relationship
    public let isFlagged: String?  // "Yes" or "No" for flagged status

    public enum CodingKeys: String, CodingKey {
        case title
        case list
        case tags
        case url
        case parentTitle
        case isFlagged
    }

    public init(
        title: String,
        list: String?,
        tags: String?,
        url: String?,
        parentTitle: String?,
        isFlagged: String?
    ) {
        self.title = title
        self.list = list
        self.tags = tags
        self.url = url
        self.parentTitle = parentTitle
        self.isFlagged = isFlagged
    }
}

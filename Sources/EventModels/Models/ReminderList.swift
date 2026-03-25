import Foundation

// MARK: - Reminder List Model

public struct ReminderList: Codable, Sendable {
    public let id: String
    public let title: String
    public let color: String?
    public let isImmutable: Bool

    public init(id: String, title: String, color: String?, isImmutable: Bool) {
        self.id = id
        self.title = title
        self.color = color
        self.isImmutable = isImmutable
    }
}

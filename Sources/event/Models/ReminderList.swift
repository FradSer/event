import EventKit
import Foundation

// MARK: - Reminder List Model

struct ReminderList: Codable {
    let id: String
    let title: String
    let color: String?
    let isImmutable: Bool

    init(from ekCalendar: EKCalendar) {
        id = ekCalendar.calendarIdentifier
        title = ekCalendar.title
        color = ekCalendar.cgColor.flatMap { color in
            String(
                format: "#%02X%02X%02X",
                Int(color.components?[0] ?? 0 * 255),
                Int(color.components?[1] ?? 0 * 255),
                Int(color.components?[2] ?? 0 * 255)
            )
        }
        isImmutable = ekCalendar.isImmutable
    }
}

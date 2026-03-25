import EventKit
import EventModels
import Foundation

extension ReminderList {
    init(from ekCalendar: EKCalendar) {
        let color = ekCalendar.cgColor.flatMap { cgColor -> String? in
            guard let components = cgColor.components, components.count >= 3 else { return nil }
            return String(
                format: "#%02X%02X%02X",
                Int(components[0] * 255),
                Int(components[1] * 255),
                Int(components[2] * 255)
            )
        }

        self.init(
            id: ekCalendar.calendarIdentifier,
            title: ekCalendar.title,
            color: color,
            isImmutable: ekCalendar.isImmutable
        )
    }
}

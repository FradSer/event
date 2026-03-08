import EventKit
import Foundation

// MARK: - Reminder Model

struct Reminder: Codable {
    let id: String
    let title: String
    let isCompleted: Bool
    let isFlagged: Bool
    let list: String
    let notes: String?
    let url: String?
    let location: String?
    let timeZone: String?
    let dueDate: String?
    let startDate: String?
    let completionDate: String?
    let creationDate: String?
    let lastModifiedDate: String?
    let externalId: String?
    let priority: Int
    let alarms: [Alarm]?
    let recurrenceRules: [RecurrenceRule]?
    let locationTrigger: LocationTrigger?

    init(from ekReminder: EKReminder, preferredTimeZone: TimeZone = .current) {
        id = ekReminder.calendarItemIdentifier
        title = ekReminder.title ?? ""
        isCompleted = ekReminder.isCompleted
        list = ekReminder.calendar?.title ?? "Unknown"
        notes = ekReminder.notes

        // Flagged status now set via Shortcut, not stored in notes field
        isFlagged = false
        url = ekReminder.url?.absoluteString
        location = ekReminder.location
        timeZone = ekReminder.timeZone?.identifier

        // Format dates
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = preferredTimeZone

        dueDate = ekReminder.dueDateComponents.flatMap { components in
            DateComponentsBuilder.toDate(from: components, timeZone: preferredTimeZone)
        }.map { formatter.string(from: $0) }

        startDate = ekReminder.startDateComponents.flatMap { components in
            DateComponentsBuilder.toDate(from: components, timeZone: preferredTimeZone)
        }.map { formatter.string(from: $0) }

        completionDate = ekReminder.completionDate.map { formatter.string(from: $0) }
        creationDate = ekReminder.creationDate.map { formatter.string(from: $0) }
        lastModifiedDate = ekReminder.lastModifiedDate.map { formatter.string(from: $0) }
        externalId = ekReminder.calendarItemExternalIdentifier
        priority = ekReminder.priority

        // Convert alarms
        alarms = ekReminder.alarms?.map { Alarm(from: $0, preferredTimeZone: preferredTimeZone) }

        // Convert recurrence rules
        recurrenceRules = ekReminder.recurrenceRules?.map { RecurrenceRule(from: $0) }

        // Extract location trigger from alarms
        locationTrigger =
            ekReminder.alarms?.compactMap { alarm in
                LocationTrigger(from: alarm)
            }.first
    }
}

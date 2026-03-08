import EventKit
import Foundation

// MARK: - Calendar Event Model

struct CalendarEvent: Codable {
    let id: String
    let title: String
    let calendar: String
    let startDate: String
    let endDate: String
    let isAllDay: Bool
    let location: String?
    let notes: String?
    let url: String?
    let timeZone: String?
    let creationDate: String?
    let lastModifiedDate: String?
    let status: String?
    let availability: String?
    let alarms: [Alarm]?
    let recurrenceRules: [RecurrenceRule]?
    let attendees: [Participant]?

    init(from ekEvent: EKEvent, preferredTimeZone: TimeZone = .current) {
        id = ekEvent.eventIdentifier ?? UUID().uuidString
        title = ekEvent.title ?? ""
        calendar = ekEvent.calendar?.title ?? "Unknown"
        isAllDay = ekEvent.isAllDay
        location = ekEvent.location
        notes = ekEvent.notes
        url = ekEvent.url?.absoluteString
        timeZone = ekEvent.timeZone?.identifier

        if ekEvent.isAllDay {
            // For all-day events, the API often returns start of the day and start of the next day.
            // When formatting all-day events, we should use the appropriate timezone to display the correct date.
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = preferredTimeZone

            // Provide fallback dates if nil to avoid fatal errors in tests
            let start = ekEvent.startDate ?? Date()
            let end = ekEvent.endDate ?? start

            startDate = formatter.string(from: start)

            // For all-day events, the end date is exclusive (the day after the event ends).
            // We'll subtract one second to get the actual last day of the event, but we'll
            // format it as just the date anyway.
            // Be careful to not subtract time from the exact same date to not flip it to the previous day if start == end
            let adjustedEndDate = (end > start) ? end.addingTimeInterval(-1) : end
            endDate = formatter.string(from: adjustedEndDate)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = preferredTimeZone

            let start = ekEvent.startDate ?? Date()
            let end = ekEvent.endDate ?? start

            startDate = formatter.string(from: start)
            endDate = formatter.string(from: end)
        }

        // Format creation and modification dates (always with time)
        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        timestampFormatter.timeZone = preferredTimeZone

        creationDate = ekEvent.creationDate.map { timestampFormatter.string(from: $0) }
        lastModifiedDate = ekEvent.lastModifiedDate.map { timestampFormatter.string(from: $0) }

        // Status
        switch ekEvent.status {
        case .none:
            status = "none"
        case .confirmed:
            status = "confirmed"
        case .tentative:
            status = "tentative"
        case .canceled:
            status = "canceled"
        @unknown default:
            status = "unknown"
        }

        // Availability
        switch ekEvent.availability {
        case .notSupported:
            availability = "notSupported"
        case .busy:
            availability = "busy"
        case .free:
            availability = "free"
        case .tentative:
            availability = "tentative"
        case .unavailable:
            availability = "unavailable"
        @unknown default:
            availability = "unknown"
        }

        // Convert alarms
        alarms = ekEvent.alarms?.map { Alarm(from: $0, preferredTimeZone: preferredTimeZone) }

        // Convert recurrence rules
        recurrenceRules = ekEvent.recurrenceRules?.map { RecurrenceRule(from: $0) }

        // Convert attendees
        attendees = ekEvent.attendees?.map { Participant(from: $0) }
    }
}

// MARK: - Participant Model

struct Participant: Codable {
    let name: String?
    let url: String
    let status: String?
    let role: String?
    let type: String?
    let isCurrentUser: Bool?

    init(from ekParticipant: EKParticipant) {
        name = ekParticipant.name
        url = ekParticipant.url.absoluteString
        isCurrentUser = ekParticipant.isCurrentUser

        // Status
        switch ekParticipant.participantStatus {
        case .unknown:
            status = "unknown"
        case .pending:
            status = "pending"
        case .accepted:
            status = "accepted"
        case .declined:
            status = "declined"
        case .tentative:
            status = "tentative"
        case .delegated:
            status = "delegated"
        case .completed:
            status = "completed"
        case .inProcess:
            status = "inProcess"
        @unknown default:
            status = "unknown"
        }

        // Role
        switch ekParticipant.participantRole {
        case .unknown:
            role = "unknown"
        case .required:
            role = "required"
        case .optional:
            role = "optional"
        case .chair:
            role = "chair"
        case .nonParticipant:
            role = "nonParticipant"
        @unknown default:
            role = "unknown"
        }

        // Type
        switch ekParticipant.participantType {
        case .unknown:
            type = "unknown"
        case .person:
            type = "person"
        case .room:
            type = "room"
        case .resource:
            type = "resource"
        case .group:
            type = "group"
        @unknown default:
            type = "unknown"
        }
    }
}

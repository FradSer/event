import EventKit
import EventModels
import Foundation

extension CalendarEvent {
  init(from ekEvent: EKEvent, preferredTimeZone: TimeZone = .current) {
    let startDate: String
    let endDate: String

    if ekEvent.isAllDay {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd"
      formatter.timeZone = preferredTimeZone

      let start = ekEvent.startDate ?? Date()
      let end = ekEvent.endDate ?? start

      startDate = formatter.string(from: start)
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

    let utcFormatter = ISO8601DateFormatter.eventISO8601

    let status: String
    switch ekEvent.status {
    case .none: status = "none"
    case .confirmed: status = "confirmed"
    case .tentative: status = "tentative"
    case .canceled: status = "canceled"
    @unknown default: status = "unknown"
    }

    let availability: String
    switch ekEvent.availability {
    case .notSupported: availability = "notSupported"
    case .busy: availability = "busy"
    case .free: availability = "free"
    case .tentative: availability = "tentative"
    case .unavailable: availability = "unavailable"
    @unknown default: availability = "unknown"
    }

    let eventId: String
    if let identifier = ekEvent.eventIdentifier {
      eventId = identifier
    } else if let externalId = ekEvent.calendarItemExternalIdentifier, !externalId.isEmpty {
      eventId = externalId
    } else {
      // Synthetic ID -- not stable if title or start time changes, but this path
      // should be unreachable for real EKEvents (they always have an identifier).
      eventId =
        "ek-\(ekEvent.calendar?.title ?? "unknown")-\(ekEvent.title ?? "untitled")-\(ekEvent.startDate?.timeIntervalSince1970 ?? 0)"
    }

    self.init(
      id: eventId,
      title: ekEvent.title ?? "",
      calendar: ekEvent.calendar?.title ?? "Unknown",
      startDate: startDate,
      endDate: endDate,
      isAllDay: ekEvent.isAllDay,
      location: ekEvent.location,
      notes: ekEvent.notes,
      url: ekEvent.url?.absoluteString,
      timeZone: ekEvent.timeZone?.identifier,
      creationDate: ekEvent.creationDate.map { utcFormatter.string(from: $0) },
      lastModifiedDate: ekEvent.lastModifiedDate.map { utcFormatter.string(from: $0) },
      status: status,
      availability: availability,
      alarms: ekEvent.alarms?.map { Alarm(from: $0, preferredTimeZone: preferredTimeZone) },
      recurrenceRules: ekEvent.recurrenceRules?.map { RecurrenceRule(from: $0) },
      attendees: ekEvent.attendees?.map { Participant(from: $0) }
    )
  }
}

extension Participant {
  init(from ekParticipant: EKParticipant) {
    let status: String
    switch ekParticipant.participantStatus {
    case .unknown: status = "unknown"
    case .pending: status = "pending"
    case .accepted: status = "accepted"
    case .declined: status = "declined"
    case .tentative: status = "tentative"
    case .delegated: status = "delegated"
    case .completed: status = "completed"
    case .inProcess: status = "inProcess"
    @unknown default: status = "unknown"
    }

    let role: String
    switch ekParticipant.participantRole {
    case .unknown: role = "unknown"
    case .required: role = "required"
    case .optional: role = "optional"
    case .chair: role = "chair"
    case .nonParticipant: role = "nonParticipant"
    @unknown default: role = "unknown"
    }

    let type: String
    switch ekParticipant.participantType {
    case .unknown: type = "unknown"
    case .person: type = "person"
    case .room: type = "room"
    case .resource: type = "resource"
    case .group: type = "group"
    @unknown default: type = "unknown"
    }

    self.init(
      name: ekParticipant.name,
      url: ekParticipant.url.absoluteString,
      status: status,
      role: role,
      type: type,
      isCurrentUser: ekParticipant.isCurrentUser
    )
  }
}

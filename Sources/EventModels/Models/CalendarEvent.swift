import Foundation

// MARK: - Calendar Event Model

public struct CalendarEvent: Codable, Sendable {
  /// Date strings written by this version use the event's timezone.
  public static let currentDateFormatVersion = 1

  public let id: String
  public let title: String
  public let calendar: String
  public let startDate: String
  public let endDate: String
  public let isAllDay: Bool
  public let location: String?
  public let notes: String?
  public let url: String?
  public let timeZone: String?
  /// `nil` identifies records written before date strings became timezone-aware.
  public let dateFormatVersion: Int?
  public let creationDate: String?
  public let lastModifiedDate: String?
  public let status: String?
  public let availability: String?
  public let alarms: [Alarm]?
  public let recurrenceRules: [RecurrenceRule]?
  public let attendees: [Participant]?

  public init(
    id: String,
    title: String,
    calendar: String,
    startDate: String,
    endDate: String,
    isAllDay: Bool,
    location: String?,
    notes: String?,
    url: String?,
    timeZone: String?,
    dateFormatVersion: Int? = CalendarEvent.currentDateFormatVersion,
    creationDate: String?,
    lastModifiedDate: String?,
    status: String?,
    availability: String?,
    alarms: [Alarm]?,
    recurrenceRules: [RecurrenceRule]?,
    attendees: [Participant]?
  ) {
    self.id = id
    self.title = title
    self.calendar = calendar
    self.startDate = startDate
    self.endDate = endDate
    self.isAllDay = isAllDay
    self.location = location
    self.notes = notes
    self.url = url
    self.timeZone = timeZone
    self.dateFormatVersion = dateFormatVersion
    self.creationDate = creationDate
    self.lastModifiedDate = lastModifiedDate
    self.status = status
    self.availability = availability
    self.alarms = alarms
    self.recurrenceRules = recurrenceRules
    self.attendees = attendees
  }
}

// MARK: - Participant Model

public struct Participant: Codable, Sendable {
  public let name: String?
  public let url: String
  public let status: String?
  public let role: String?
  public let type: String?
  public let isCurrentUser: Bool?

  public init(
    name: String?,
    url: String,
    status: String?,
    role: String?,
    type: String?,
    isCurrentUser: Bool?
  ) {
    self.name = name
    self.url = url
    self.status = status
    self.role = role
    self.type = type
    self.isCurrentUser = isCurrentUser
  }
}

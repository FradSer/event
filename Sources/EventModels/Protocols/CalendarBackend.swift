import Foundation

// MARK: - Calendar Backend Protocol

public protocol CalendarBackend: Sendable {
  func fetchEvents(start: String, end: String, calendarName: String?) async throws
    -> [CalendarEvent]
  func fetchEvent(byId id: String) async throws -> CalendarEvent
  func createEvent(_ params: CreateEventParams) async throws -> CalendarEvent
  func updateEvent(id: String, params: UpdateEventParams) async throws -> CalendarEvent
  func deleteEvent(id: String) async throws
}

// MARK: - Create Event Params

public struct CreateEventParams: Sendable {
  public let title: String
  public let calendarName: String?
  public let startDate: String
  public let endDate: String
  public let isAllDay: Bool
  public let location: String?
  public let notes: String?
  public let url: String?
  public let availability: CalendarEventAvailability?
  public let alarmMinutes: [Int]?
  public let timeZoneIdentifier: String?

  public init(
    title: String,
    calendarName: String? = nil,
    startDate: String,
    endDate: String,
    isAllDay: Bool = false,
    location: String? = nil,
    notes: String? = nil,
    url: String? = nil,
    availability: CalendarEventAvailability? = nil,
    alarmMinutes: [Int]? = nil,
    timeZoneIdentifier: String? = nil
  ) {
    self.title = title
    self.calendarName = calendarName
    self.startDate = startDate
    self.endDate = endDate
    self.isAllDay = isAllDay
    self.location = location
    self.notes = notes
    self.url = url
    self.availability = availability
    self.alarmMinutes = alarmMinutes
    self.timeZoneIdentifier = timeZoneIdentifier
  }
}

// MARK: - Update Event Params

public struct UpdateEventParams: Sendable {
  public let title: String?
  public let startDate: String?
  public let endDate: String?
  public let isAllDay: Bool?
  public let location: String?
  public let notes: String?
  public let url: String?
  public let clearURL: Bool
  public let availability: CalendarEventAvailability?
  public let alarmMinutes: [Int]?
  public let addAlarmMinutes: [Int]?
  public let timeZoneIdentifier: String?

  public init(
    title: String? = nil,
    startDate: String? = nil,
    endDate: String? = nil,
    isAllDay: Bool? = nil,
    location: String? = nil,
    notes: String? = nil,
    url: String? = nil,
    clearURL: Bool = false,
    availability: CalendarEventAvailability? = nil,
    alarmMinutes: [Int]? = nil,
    addAlarmMinutes: [Int]? = nil,
    timeZoneIdentifier: String? = nil
  ) {
    self.title = title
    self.startDate = startDate
    self.endDate = endDate
    self.isAllDay = isAllDay
    self.location = location
    self.notes = notes
    self.url = url
    self.clearURL = clearURL
    self.availability = availability
    self.alarmMinutes = alarmMinutes
    self.addAlarmMinutes = addAlarmMinutes
    self.timeZoneIdentifier = timeZoneIdentifier
  }
}

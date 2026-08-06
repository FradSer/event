import AppleSyncKit
import EventModels
import Foundation
import SQLite

// MARK: - SQLite Calendar Service

/// SQLite-backed calendar service that stores CalendarEvent as JSON in the database.
public actor SQLiteCalendarService: CalendarBackend {
  private let connection: Connection

  public init(connection: Connection) {
    self.connection = connection
  }

  // MARK: - Fetch

  public func fetchEvents(
    start: String,
    end: String,
    calendarName: String?
  ) async throws -> [CalendarEvent] {
    var sql = """
      SELECT data FROM calendar_events
      WHERE deleted = 0
        AND json_extract(data, '$.startDate') <= ?
        AND json_extract(data, '$.endDate') >= ?
      """
    var bindings: [Binding?] = [end, start]

    if let calendarName {
      sql += " AND json_extract(data, '$.calendar') = ?"
      bindings.append(calendarName)
    }

    sql += " ORDER BY json_extract(data, '$.startDate') ASC"

    return try connection.prepare(sql, bindings).map { row in
      try Self.decodeEvent(from: row[0])
    }
  }

  public func fetchEvent(byId id: String) async throws -> CalendarEvent {
    let sql = "SELECT data FROM calendar_events WHERE id = ? AND deleted = 0"
    for row in try connection.prepare(sql, [id]) {
      return try Self.decodeEvent(from: row[0])
    }
    throw EventCLIError.notFound("Calendar event with ID '\(id)' not found")
  }

  // MARK: - Create

  public func createEvent(_ params: CreateEventParams) async throws -> CalendarEvent {
    let timeZone = try TimeZoneValidator.resolve(identifier: params.timeZoneIdentifier)
    if params.isAllDay, timeZone != nil {
      throw EventCLIError.invalidInput("--timezone is only supported for timed events")
    }
    let now = ISO8601DateFormatter.syncISO8601.string(from: Date())
    let id = UUID().uuidString

    let calendarName = params.calendarName ?? "Calendar"
    let event = CalendarEvent(
      id: id,
      title: params.title,
      calendar: calendarName,
      startDate: params.startDate,
      endDate: params.endDate,
      isAllDay: params.isAllDay,
      location: params.location,
      notes: params.notes,
      url: params.url,
      timeZone: timeZone?.identifier ?? (params.isAllDay ? nil : TimeZone.current.identifier),
      creationDate: now,
      lastModifiedDate: now,
      status: nil,
      availability: nil,
      alarms: nil,
      recurrenceRules: nil,
      attendees: nil
    )

    let jsonString = try Self.encode(event)

    try connection.run(
      """
      INSERT INTO calendar_events (id, data, last_modified, deleted, updated_at, is_local_only)
      VALUES (?, ?, ?, 0, NULL, 1)
      """,
      id, jsonString, now
    )

    return event
  }

  // MARK: - Update

  public func updateEvent(
    id: String,
    params: UpdateEventParams
  ) async throws -> CalendarEvent {
    let existing = try await fetchEvent(byId: id)
    let timeZone = try TimeZoneValidator.resolve(identifier: params.timeZoneIdentifier)
    let isAllDay = params.isAllDay ?? existing.isAllDay
    if isAllDay, timeZone != nil {
      throw EventCLIError.invalidInput("--timezone is only supported for timed events")
    }
    let existingTimeZone =
      try TimeZoneValidator.resolve(identifier: existing.timeZone) ?? .current
    let startDate: String
    if let startDateInput = params.startDate {
      startDate = startDateInput
    } else if let timeZone, !isAllDay {
      startDate = try DateValidator.convertDateTime(
        existing.startDate, from: existingTimeZone, to: timeZone)
    } else {
      startDate = existing.startDate
    }
    let endDate: String
    if let endDateInput = params.endDate {
      endDate = endDateInput
    } else if let timeZone, !isAllDay {
      endDate = try DateValidator.convertDateTime(
        existing.endDate, from: existingTimeZone, to: timeZone)
    } else {
      endDate = existing.endDate
    }
    let now = ISO8601DateFormatter.syncISO8601.string(from: Date())

    let updatedEvent = CalendarEvent(
      id: existing.id,
      title: params.title ?? existing.title,
      calendar: existing.calendar,
      startDate: startDate,
      endDate: endDate,
      isAllDay: isAllDay,
      location: params.location ?? existing.location,
      notes: params.notes ?? existing.notes,
      url: params.url ?? existing.url,
      timeZone: isAllDay ? nil : timeZone?.identifier ?? existing.timeZone,
      creationDate: existing.creationDate,
      lastModifiedDate: now,
      status: existing.status,
      availability: existing.availability,
      alarms: existing.alarms,
      recurrenceRules: existing.recurrenceRules,
      attendees: existing.attendees
    )

    let jsonString = try Self.encode(updatedEvent)

    try connection.run(
      """
      UPDATE calendar_events
      SET data = ?, last_modified = ?, updated_at = NULL, is_local_only = 1
      WHERE id = ? AND deleted = 0
      """,
      jsonString, now, id
    )

    return updatedEvent
  }

  // MARK: - Delete

  public func deleteEvent(id: String) async throws {
    let now = ISO8601DateFormatter.syncISO8601.string(from: Date())
    try connection.run(
      """
      UPDATE calendar_events
      SET deleted = 1, last_modified = ?, updated_at = NULL, is_local_only = 1
      WHERE id = ? AND deleted = 0
      """,
      now, id
    )

    if connection.changes == 0 {
      throw EventCLIError.notFound("Calendar event with ID '\(id)' not found")
    }
  }

  // MARK: - Private Helpers

  private static func decodeEvent(from value: Binding?) throws -> CalendarEvent {
    guard let jsonString = value as? String,
      let jsonData = jsonString.data(using: .utf8)
    else {
      throw EventCLIError.unknown("Failed to decode calendar event data")
    }
    return try JSONDecoder().decode(CalendarEvent.self, from: jsonData)
  }

  private static func encode(_ event: CalendarEvent) throws -> String {
    let data = try JSONEncoder().encode(event)
    guard let jsonString = String(data: data, encoding: .utf8) else {
      throw EventCLIError.unknown("Failed to encode calendar event to JSON")
    }
    return jsonString
  }
}

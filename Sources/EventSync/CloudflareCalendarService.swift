import AppleSyncKit
import EventModels
import Foundation

// MARK: - Cloudflare Calendar Service

/// Reads and writes calendar events directly against Cloudflare D1, transparently
/// decrypting sensitive fields on read and encrypting on write via
/// `EventEncryptor`. Used by the advanced `event sync calendar` subcommands.
public actor CloudflareCalendarService: CalendarBackend {
  private let client: D1SyncClient
  private let encryptor: EventEncryptor

  public init(client: D1SyncClient, encryptor: EventEncryptor) {
    self.client = client
    self.encryptor = encryptor
  }

  // MARK: - Fetch

  public func fetchEvents(
    start: String,
    end: String,
    calendarName: String?
  ) async throws -> [CalendarEvent] {
    let all: [CalendarEvent] = try await client.pullAll(entity: "calendar_events")
    var filtered = all

    if let calendarName {
      filtered = filtered.filter { $0.calendar == calendarName }
    }

    let range = CalendarEvent.syncDateRange(start: start, end: end)
    filtered = filtered.filter { $0.syncDateRange().overlaps(range) }

    return try await encryptor.decryptEvents(filtered)
  }

  public func fetchEvent(byId id: String) async throws -> CalendarEvent {
    let all: [CalendarEvent] = try await client.pullAll(entity: "calendar_events")
    guard let event = all.first(where: { $0.id == id }) else {
      throw EventCLIError.notFound("Calendar event with ID '\(id)' not found")
    }
    return try await encryptor.decryptEvents([event])[0]
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
    let plainEvent = CalendarEvent(
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

    let d1Events = try await encryptor.encryptEvents([plainEvent])
    _ = try await client.push(entity: "calendar_events", items: d1Events, id: { $0.id })
    return plainEvent
  }

  // MARK: - Update

  public func updateEvent(
    id: String,
    params: UpdateEventParams
  ) async throws -> CalendarEvent {
    let all: [CalendarEvent] = try await client.pullAll(entity: "calendar_events")
    guard let encrypted = all.first(where: { $0.id == id }) else {
      throw EventCLIError.notFound("Calendar event with ID '\(id)' not found")
    }

    let existing = try await encryptor.decryptEvents([encrypted])[0]
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
    } else if let timeZone, !isAllDay, existing.usesEventTimeZoneDateFormat {
      startDate =
        (try? DateValidator.convertDateTime(
          existing.startDate, from: existingTimeZone, to: timeZone)) ?? existing.startDate
    } else {
      startDate = existing.startDate
    }
    let endDate: String
    if let endDateInput = params.endDate {
      endDate = endDateInput
    } else if let timeZone, !isAllDay, existing.usesEventTimeZoneDateFormat {
      endDate =
        (try? DateValidator.convertDateTime(
          existing.endDate, from: existingTimeZone, to: timeZone)) ?? existing.endDate
    } else {
      endDate = existing.endDate
    }
    let now = ISO8601DateFormatter.syncISO8601.string(from: Date())

    let updatedPlain = CalendarEvent(
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
      dateFormatVersion: existing.dateFormatVersion,
      creationDate: existing.creationDate,
      lastModifiedDate: now,
      status: existing.status,
      availability: existing.availability,
      alarms: existing.alarms,
      recurrenceRules: existing.recurrenceRules,
      attendees: existing.attendees
    )

    let d1Events = try await encryptor.encryptEvents([updatedPlain])
    _ = try await client.push(entity: "calendar_events", items: d1Events, id: { $0.id })
    return updatedPlain
  }

  // MARK: - Delete

  public func deleteEvent(id: String) async throws {
    let result = try await client.delete(
      entity: "calendar_events", id: id,
      lastModified: ISO8601DateFormatter.syncISO8601.string(from: Date()))
    guard result.accepted else {
      throw SyncError.unknown(
        "Calendar event deletion was rejected by last-write-wins conflict resolution")
    }
  }

}

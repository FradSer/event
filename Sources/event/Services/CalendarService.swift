#if canImport(EventKit)

  import EventKit
  import EventModels
  import Foundation

  // MARK: - Calendar Service

  actor CalendarService {
    private let eventStore = EKEventStore()
    private let permissionService = PermissionService()

    /// Fetch calendar events
    func fetchEvents(
      startDate: String? = nil,
      endDate: String? = nil,
      calendarName: String? = nil
    ) async throws -> [CalendarEvent] {
      try await permissionService.ensureCalendarAccess()

      let start = try startDate.flatMap { try Date.validated(dateString: $0) } ?? Date()
      let end =
        try endDate.flatMap { try Date.validated(dateString: $0) }
        ?? Calendar.current.date(byAdding: .month, value: 1, to: start)
        ?? Date()

      let calendars: [EKCalendar]
      if let calendarName = calendarName {
        calendars = eventStore.calendars(for: .event).filter { $0.title == calendarName }
        if calendars.isEmpty {
          throw EventCLIError.notFound("Calendar '\(calendarName)' not found")
        }
      } else {
        calendars = eventStore.calendars(for: .event)
      }

      let predicate = eventStore.predicateForEvents(
        withStart: start, end: end, calendars: calendars)
      let ekEvents = eventStore.events(matching: predicate)

      return ekEvents.map { CalendarEvent(from: $0) }
    }

    /// Returns whether an event with the given EventKit identifier still exists locally.
    func eventExists(id: String) async -> Bool {
      eventStore.event(withIdentifier: id) != nil
    }

    /// Create a calendar event
    func createEvent(
      title: String,
      startDate: String,
      endDate: String,
      calendarName: String? = nil,
      location: String? = nil,
      notes: String? = nil,
      url: String? = nil,
      timeZoneIdentifier: String? = nil,
      dateFormatVersion: Int? = CalendarEvent.currentDateFormatVersion
    ) async throws -> CalendarEvent {
      try await permissionService.ensureCalendarAccess()

      // Detect if this is an all-day event
      let isAllDay = Date.isAllDayFormat(startDate) && Date.isAllDayFormat(endDate)
      if isAllDay, timeZoneIdentifier != nil {
        throw EventCLIError.invalidInput("--timezone is only supported for timed events")
      }
      let eventTimeZone = try TimeZoneValidator.resolve(identifier: timeZoneIdentifier)

      let start: Date
      let end: Date

      let parsingTimeZone =
        dateFormatVersion == CalendarEvent.currentDateFormatVersion
        ? eventTimeZone ?? .current
        : .current

      if isAllDay {
        start = try Date.validated(dateString: startDate)
        end = try Date.validated(dateString: endDate)
      } else {
        start = try Date.validated(dateTimeString: startDate, timeZone: parsingTimeZone)
        end = try Date.validated(dateTimeString: endDate, timeZone: parsingTimeZone)
      }

      try DateValidator.validateDateRange(start: start, end: end)

      let ekEvent = EKEvent(eventStore: eventStore)
      ekEvent.title = title
      ekEvent.startDate = start
      ekEvent.endDate = end
      ekEvent.isAllDay = isAllDay
      ekEvent.location = location
      ekEvent.notes = notes
      ekEvent.timeZone = eventTimeZone
      if let urlString = url, let validURL = URL(string: urlString) {
        ekEvent.url = validURL
      }

      // Set calendar
      if let calendarName = calendarName {
        let calendars = eventStore.calendars(for: .event).filter { $0.title == calendarName }
        guard let calendar = calendars.first else {
          throw EventCLIError.notFound("Calendar '\(calendarName)' not found")
        }
        ekEvent.calendar = calendar
      } else {
        ekEvent.calendar = eventStore.defaultCalendarForNewEvents
      }

      try eventStore.save(ekEvent, span: .thisEvent, commit: true)
      return CalendarEvent(from: ekEvent)
    }

    /// Update a calendar event
    func updateEvent(
      id: String,
      title: String? = nil,
      startDate: String? = nil,
      endDate: String? = nil,
      location: String? = nil,
      notes: String? = nil,
      url: String? = nil,
      timeZoneIdentifier: String? = nil,
      clearTimeZone: Bool = false,
      dateFormatVersion: Int? = CalendarEvent.currentDateFormatVersion
    ) async throws -> CalendarEvent {
      try await permissionService.ensureCalendarAccess()

      guard let ekEvent = eventStore.event(withIdentifier: id) else {
        throw EventCLIError.notFound("Event with ID '\(id)' not found")
      }

      let updatedTimeZone = try TimeZoneValidator.resolve(identifier: timeZoneIdentifier)
      let parsingTimeZone: TimeZone
      if dateFormatVersion == CalendarEvent.currentDateFormatVersion {
        parsingTimeZone = CalendarTimeZoneUpdate.parsingTimeZone(
          clearTimeZone: clearTimeZone,
          requested: updatedTimeZone,
          existing: ekEvent.timeZone
        )
      } else {
        parsingTimeZone = .current
      }
      let dateResolution = try CalendarDateInputResolver.resolve(
        currentIsAllDay: ekEvent.isAllDay,
        currentStart: ekEvent.startDate ?? Date(),
        currentEnd: ekEvent.endDate ?? Date(),
        startInput: startDate,
        endInput: endDate,
        timeZone: parsingTimeZone
      )

      if dateResolution.isAllDay, timeZoneIdentifier != nil {
        throw EventCLIError.invalidInput("--timezone is only supported for timed events")
      }

      if let title = title {
        ekEvent.title = title
      }

      if startDate != nil || endDate != nil {
        ekEvent.startDate = dateResolution.start
        ekEvent.endDate = dateResolution.end
        ekEvent.isAllDay = dateResolution.isAllDay
      }

      ekEvent.timeZone = CalendarTimeZoneUpdate.resolvedTimeZone(
        isAllDay: dateResolution.isAllDay,
        clearTimeZone: clearTimeZone,
        requested: updatedTimeZone,
        existing: ekEvent.timeZone
      )

      if let location = location {
        ekEvent.location = location
      }

      if let notes = notes {
        ekEvent.notes = notes
      }

      if let urlString = url, let validURL = URL(string: urlString) {
        ekEvent.url = validURL
      }

      try DateValidator.validateDateRange(start: ekEvent.startDate, end: ekEvent.endDate)

      try eventStore.save(ekEvent, span: .thisEvent, commit: true)
      return CalendarEvent(from: ekEvent)
    }

    /// Delete a calendar event
    func deleteEvent(id: String, span: String = "this") async throws {
      try await permissionService.ensureCalendarAccess()

      guard let ekEvent = eventStore.event(withIdentifier: id) else {
        throw EventCLIError.notFound("Event with ID '\(id)' not found")
      }

      let ekSpan: EKSpan
      switch span.lowercased() {
      case "this":
        ekSpan = .thisEvent
      case "future":
        ekSpan = .futureEvents
      case "all":
        ekSpan = .futureEvents
      default:
        throw EventCLIError.invalidInput(
          "Invalid span '\(span)'. Must be 'this' or 'future'.")
      }

      try eventStore.remove(ekEvent, span: ekSpan, commit: true)
    }
  }

  // MARK: - CalendarBackend Conformance

  extension CalendarService: CalendarBackend {
    func fetchEvents(start: String, end: String, calendarName: String?) async throws
      -> [CalendarEvent]
    {
      try await fetchEvents(startDate: start, endDate: end, calendarName: calendarName)
    }

    func fetchEvent(byId id: String) async throws -> CalendarEvent {
      try await permissionService.ensureCalendarAccess()
      guard let ekEvent = eventStore.event(withIdentifier: id) else {
        throw EventCLIError.notFound("Event with ID '\(id)' not found")
      }
      return CalendarEvent(from: ekEvent)
    }

    func createEvent(_ params: CreateEventParams) async throws -> CalendarEvent {
      try await createEvent(
        title: params.title,
        startDate: params.startDate,
        endDate: params.endDate,
        calendarName: params.calendarName,
        location: params.location,
        notes: params.notes,
        url: params.url,
        timeZoneIdentifier: params.timeZoneIdentifier
      )
    }

    func updateEvent(id: String, params: UpdateEventParams) async throws -> CalendarEvent {
      try await updateEvent(
        id: id,
        title: params.title,
        startDate: params.startDate,
        endDate: params.endDate,
        location: params.location,
        notes: params.notes,
        url: params.url,
        timeZoneIdentifier: params.timeZoneIdentifier
      )
    }

    func deleteEvent(id: String) async throws {
      try await deleteEvent(id: id, span: "this")
    }
  }

#endif

import EventKit
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

        let start = startDate.flatMap { Date.from(dateString: $0) } ?? Date()
        let end =
            endDate.flatMap { Date.from(dateString: $0) }
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

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let ekEvents = eventStore.events(matching: predicate)

        return ekEvents.map { CalendarEvent(from: $0) }
    }

    /// Create a calendar event
    func createEvent(
        title: String,
        startDate: String,
        endDate: String,
        calendarName: String? = nil,
        location: String? = nil,
        notes: String? = nil
    ) async throws -> CalendarEvent {
        try await permissionService.ensureCalendarAccess()

        // Detect if this is an all-day event
        let isAllDay = Date.isAllDayFormat(startDate) && Date.isAllDayFormat(endDate)

        let start: Date
        let end: Date

        if isAllDay {
            start = try Date.validated(dateString: startDate)
            end = try Date.validated(dateString: endDate)
        } else {
            start = try Date.validated(dateTimeString: startDate)
            end = try Date.validated(dateTimeString: endDate)
        }

        try DateValidator.validateDateRange(start: start, end: end)

        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.title = title
        ekEvent.startDate = start
        ekEvent.endDate = end
        ekEvent.isAllDay = isAllDay
        ekEvent.location = location
        ekEvent.notes = notes

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
        notes: String? = nil
    ) async throws -> CalendarEvent {
        try await permissionService.ensureCalendarAccess()

        guard let ekEvent = eventStore.event(withIdentifier: id) else {
            throw EventCLIError.notFound("Event with ID '\(id)' not found")
        }

        if let title = title {
            ekEvent.title = title
        }

        if let startDateString = startDate {
            let start = try Date.validated(dateTimeString: startDateString)
            ekEvent.startDate = start
        }

        if let endDateString = endDate {
            let end = try Date.validated(dateTimeString: endDateString)
            ekEvent.endDate = end
        }

        if let location = location {
            ekEvent.location = location
        }

        if let notes = notes {
            ekEvent.notes = notes
        }

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
        case "all":
            ekSpan = .futureEvents
        default:
            ekSpan = .thisEvent
        }

        try eventStore.remove(ekEvent, span: ekSpan, commit: true)
    }
}

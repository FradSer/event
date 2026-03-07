import EventKit
import Foundation

// MARK: - List Service

actor ListService {
    private let eventStore = EKEventStore()
    private let permissionService = PermissionService()

    /// Fetch all reminder lists
    func fetchLists() async throws -> [ReminderList] {
        try await permissionService.ensureRemindersAccess()

        let calendars = eventStore.calendars(for: .reminder)
        return calendars.map { ReminderList(from: $0) }
    }

    /// Create a new reminder list
    func createList(name: String) async throws -> ReminderList {
        try await permissionService.ensureRemindersAccess()

        let calendar = EKCalendar(for: .reminder, eventStore: eventStore)
        calendar.title = name

        // Find a source that actually supports reminders (has existing reminder calendars)
        let existingReminderCalendars = eventStore.calendars(for: .reminder)
        let validSources = Set(existingReminderCalendars.map { $0.source })

        guard let source = validSources.first else {
            throw EventCLIError.eventKitError("No suitable source found for creating reminder list")
        }
        calendar.source = source

        try eventStore.saveCalendar(calendar, commit: true)
        return ReminderList(from: calendar)
    }

    /// Update a reminder list
    func updateList(id: String, name: String) async throws -> ReminderList {
        try await permissionService.ensureRemindersAccess()

        guard let calendar = eventStore.calendar(withIdentifier: id) else {
            throw EventCLIError.notFound("List with ID '\(id)' not found")
        }

        if calendar.isImmutable {
            throw EventCLIError.invalidInput("Cannot modify system list '\(calendar.title)'")
        }

        calendar.title = name
        try eventStore.saveCalendar(calendar, commit: true)
        return ReminderList(from: calendar)
    }

    /// Delete a reminder list
    func deleteList(id: String) async throws {
        try await permissionService.ensureRemindersAccess()

        guard let calendar = eventStore.calendar(withIdentifier: id) else {
            throw EventCLIError.notFound("List with ID '\(id)' not found")
        }

        if calendar.isImmutable {
            throw EventCLIError.invalidInput("Cannot delete system list '\(calendar.title)'")
        }

        try eventStore.removeCalendar(calendar, commit: true)
    }
}

import EventKit
import Foundation

// MARK: - Reminder Service

actor ReminderService {
    private let eventStore = EKEventStore()
    private let permissionService = PermissionService()

    /// Fetch reminders with optional filters
    func fetchReminders(
        listName: String? = nil,
        showCompleted: Bool = false
    ) async throws -> [Reminder] {
        try await permissionService.ensureRemindersAccess()

        let calendars: [EKCalendar]
        if let listName = listName {
            calendars = eventStore.calendars(for: .reminder).filter { $0.title == listName }
            if calendars.isEmpty {
                throw EventCLIError.notFound("List '\(listName)' not found")
            }
        } else {
            calendars = eventStore.calendars(for: .reminder)
        }

        let predicate = eventStore.predicateForReminders(in: calendars)

        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { ekReminders in
                guard let ekReminders = ekReminders else {
                    continuation.resume(throwing: EventCLIError.eventKitError("Failed to fetch reminders"))
                    return
                }

                var reminders = ekReminders.map { Reminder(from: $0) }

                // Filter by completion status
                if !showCompleted {
                    reminders = reminders.filter { !$0.isCompleted }
                }

                continuation.resume(returning: reminders)
            }
        }
    }

    /// Create a new reminder
    func createReminder(
        title: String,
        listName: String? = nil,
        notes: String? = nil,
        dueDate: String? = nil,
        priority: Int? = nil,
        tags: [String]? = nil,
        subtasks: [String]? = nil
    ) async throws -> Reminder {
        try await permissionService.ensureRemindersAccess()

        // Check if the Advanced Reminder Shortcut is installed
        let shortcutsService = ShortcutsService()
        let advancedShortcutName = "CreateAdvancedReminder"
        let isShortcutInstalled = try await shortcutsService.isShortcutInstalled(name: advancedShortcutName)

        if isShortcutInstalled {
            let payload = ShortcutReminderPayload(
                title: title,
                listName: listName,
                notes: notes,
                tags: tags,
                subtasks: subtasks
            )

            do {
                let reminderUUID = try await shortcutsService.runShortcut(name: advancedShortcutName, input: payload)
                if let ekReminder = eventStore.calendarItem(withIdentifier: reminderUUID) as? EKReminder {
                    return Reminder(from: ekReminder)
                } else {
                    // Fallback if UUID not found
                    print("Warning: Shortcut created reminder but UUID '\(reminderUUID)' could not be fetched. Falling back to EventKit.")
                }
            } catch {
                print("Warning: Shortcut execution failed (\(error.localizedDescription)). Falling back to EventKit.")
            }
        } else if tags != nil || subtasks != nil {
            print("Warning: Creating reminders with tags or subtasks via EventKit uses the notes field workaround.")
            print("To get native tags and subtasks, please install the CreateAdvancedReminder shortcut:")
            print("https://www.icloud.com/shortcuts/YOUR_SHORTCUT_LINK_HERE")
        }

        let ekReminder = EKReminder(eventStore: eventStore)
        ekReminder.title = title

        // Set calendar (list)
        if let listName = listName {
            let calendars = eventStore.calendars(for: .reminder).filter { $0.title == listName }
            guard let calendar = calendars.first else {
                throw EventCLIError.notFound("List '\(listName)' not found")
            }
            ekReminder.calendar = calendar
        } else {
            ekReminder.calendar = eventStore.defaultCalendarForNewReminders()
        }

        // Set notes with tags
        let subtaskItems = subtasks?.map { Subtask(id: UUID().uuidString, title: $0, isCompleted: false) } ?? []
        let createParsed = ParsedNotes(userNotes: notes ?? "", tags: tags ?? [], subtasks: subtaskItems)
        let createSerialized = NotesParser.serialize(createParsed)
        if !createSerialized.isEmpty {
            ekReminder.notes = createSerialized
        }

        // Set due date
        if let dueDateString = dueDate {
            let date = try Date.validated(dateTimeString: dueDateString)
            let components = DateComponentsBuilder.build(from: date, timeZone: .current)
            ekReminder.dueDateComponents = components
        }

        // Set priority
        if let priority = priority {
            ekReminder.priority = priority
        }

        try eventStore.save(ekReminder, commit: true)
        return Reminder(from: ekReminder)
    }

    /// Update an existing reminder
    func updateReminder(
        id: String,
        title: String? = nil,
        completed: Bool? = nil,
        notes: String? = nil,
        dueDate: String? = nil,
        priority: Int? = nil,
        tags: [String]? = nil
    ) async throws -> Reminder {
        try await permissionService.ensureRemindersAccess()

        guard let ekReminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventCLIError.notFound("Reminder with ID '\(id)' not found")
        }

        if let title = title {
            ekReminder.title = title
        }

        if let completed = completed {
            ekReminder.isCompleted = completed
        }

        if notes != nil || tags != nil {
            var parsed = NotesParser.parse(ekReminder.notes)
            if let notes = notes { parsed.userNotes = notes }
            if let tags = tags { parsed.tags = tags }
            ekReminder.notes = NotesParser.serialize(parsed)
        }

        if let dueDateString = dueDate {
            let date = try Date.validated(dateTimeString: dueDateString)
            let components = DateComponentsBuilder.build(from: date, timeZone: .current)
            ekReminder.dueDateComponents = components
        }

        if let priority = priority {
            ekReminder.priority = priority
        }

        try eventStore.save(ekReminder, commit: true)
        return Reminder(from: ekReminder)
    }

    /// Delete a reminder
    func deleteReminder(id: String) async throws {
        try await permissionService.ensureRemindersAccess()

        guard let ekReminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventCLIError.notFound("Reminder with ID '\(id)' not found")
        }

        try eventStore.remove(ekReminder, commit: true)
    }
}

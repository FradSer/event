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
        url: String? = nil,
        dueDate: String? = nil,
        priority: Int? = nil,
        tags: String? = nil,
        parentTitle: String? = nil
    ) async throws -> Reminder {
        try await permissionService.ensureRemindersAccess()

        // Step 1: Create basic reminder via EventKit
        let reminderId = try createViaEventKit(
            title: title,
            listName: listName,
            notes: notes,
            dueDate: dueDate,
            priority: priority
        )

        // Step 2: Post-process with advanced features if needed
        if needsAdvancedProcessing(tags: tags, url: url, parentTitle: parentTitle) {
            try await postProcessReminder(
                id: reminderId,
                tags: tags,
                url: url,
                parentTitle: parentTitle
            )
        }

        // Step 3: Fetch and return final state
        return try fetchReminder(id: reminderId)
    }

    /// Update an existing reminder
    func updateReminder(
        id: String,
        title: String? = nil,
        completed: Bool? = nil,
        notes: String? = nil,
        dueDate: String? = nil,
        priority: Int? = nil,
        tags: String? = nil,
        url: String? = nil,
        parentTitle: String? = nil
    ) async throws -> Reminder {
        try await permissionService.ensureRemindersAccess()

        // Step 1: Update basic properties via EventKit
        try updateViaEventKit(
            id: id,
            title: title,
            completed: completed,
            notes: notes,
            dueDate: dueDate,
            priority: priority
        )

        // Step 2: Post-process with advanced features if needed
        if needsAdvancedProcessing(tags: tags, url: url, parentTitle: parentTitle) {
            try await postProcessReminder(
                id: id,
                tags: tags,
                url: url,
                parentTitle: parentTitle
            )
        }

        // Step 3: Fetch and return final state
        return try fetchReminder(id: id)
    }

    /// Delete a reminder
    func deleteReminder(id: String) async throws {
        try await permissionService.ensureRemindersAccess()

        guard let ekReminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventCLIError.notFound("Reminder with ID '\(id)' not found")
        }

        try eventStore.remove(ekReminder, commit: true)
    }

    // MARK: - Helper Functions

    /// Check if advanced processing is needed
    private func needsAdvancedProcessing(tags: String?, url: String?, parentTitle: String?) -> Bool {
        return tags != nil || url != nil || parentTitle != nil
    }

    /// Fetch a reminder by ID
    private func fetchReminder(id: String) throws -> Reminder {
        guard let ekReminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventCLIError.notFound("Reminder with ID '\(id)' not found")
        }
        return Reminder(from: ekReminder)
    }

    /// Post-process reminder with advanced features
    private func postProcessReminder(
        id: String,
        tags: String?,
        url: String?,
        parentTitle: String?
    ) async throws {
        // Get reminder details for shortcut
        guard let ekReminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventCLIError.notFound("Reminder with ID '\(id)' not found")
        }

        let title = ekReminder.title ?? ""
        let listName = ekReminder.calendar?.title ?? "Reminders"

        let shortcutsService = ShortcutsService()
        let shortcutName = "AdvancedReminderEdit"
        let isShortcutInstalled = try await shortcutsService.isShortcutInstalled(name: shortcutName)

        if isShortcutInstalled {
            let payload = AdvancedReminderEditPayload(
                title: title,
                list: listName,
                tags: tags,
                url: url,
                parentTitle: parentTitle
            )

            do {
                _ = try await shortcutsService.runShortcut(name: shortcutName, input: payload)
                print("Shortcut executed successfully")
                return
            } catch {
                print("Warning: Shortcut execution failed (\(error.localizedDescription)). Falling back to EventKit.")
            }
        } else {
            print("Note: AdvancedReminderEdit shortcut not found.")
            print("Install it at: https://www.icloud.com/shortcuts/b578334075754da9ba6e50b501515808")
        }

        // Fallback processing
        try await fallbackProcessing(id: id, tags: tags, url: url, parentTitle: parentTitle)
    }

    /// Fallback processing when shortcut is not available
    private func fallbackProcessing(
        id: String,
        tags: String?,
        url: String?,
        parentTitle: String?
    ) async throws {
        if let tags = tags {
            try updateTagsViaNotesField(id: id, tags: tags)
            print("Note: Tags updated via notes field workaround.")
            print("For native tags, install the AdvancedReminderEdit shortcut:")
            print("https://www.icloud.com/shortcuts/b578334075754da9ba6e50b501515808")
        }

        if let url = url {
            try updateURLViaEventKit(id: id, url: url)
        }

        if parentTitle != nil {
            print("Warning: Creating subtask relationships requires the AdvancedReminderEdit shortcut.")
            print("Install it at: https://www.icloud.com/shortcuts/b578334075754da9ba6e50b501515808")
            print("The reminder was created as a standalone item.")
        }
    }

    /// Update tags via notes field workaround
    private func updateTagsViaNotesField(id: String, tags: String) throws {
        guard let ekReminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventCLIError.notFound("Reminder with ID '\(id)' not found")
        }

        // Split tags string into array
        let tagArray = tags.components(separatedBy: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        var parsed = NotesParser.parse(ekReminder.notes)
        parsed.tags = tagArray
        ekReminder.notes = NotesParser.serialize(parsed)
        try eventStore.save(ekReminder, commit: true)
    }

    /// Update URL via EventKit
    private func updateURLViaEventKit(id: String, url: String) throws {
        guard let ekReminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventCLIError.notFound("Reminder with ID '\(id)' not found")
        }

        if let validURL = URL(string: url) {
            ekReminder.url = validURL
            try eventStore.save(ekReminder, commit: true)
        }
    }

    /// Create reminder via EventKit (basic properties only)
    private func createViaEventKit(
        title: String,
        listName: String?,
        notes: String?,
        dueDate: String?,
        priority: Int?
    ) throws -> String {
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

        // Set notes (without tags - those will be added in post-processing)
        if let notes = notes, !notes.isEmpty {
            ekReminder.notes = notes
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
        return ekReminder.calendarItemIdentifier
    }

    /// Update reminder via EventKit (basic properties only)
    private func updateViaEventKit(
        id: String,
        title: String?,
        completed: Bool?,
        notes: String?,
        dueDate: String?,
        priority: Int?
    ) throws {
        guard let ekReminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventCLIError.notFound("Reminder with ID '\(id)' not found")
        }

        if let title = title {
            ekReminder.title = title
        }

        if let completed = completed {
            ekReminder.isCompleted = completed
        }

        if let notes = notes {
            var parsed = NotesParser.parse(ekReminder.notes)
            parsed.userNotes = notes
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
    }
}

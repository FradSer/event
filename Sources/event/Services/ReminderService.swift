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
        parentTitle: String? = nil,
        flagged: Bool? = nil,
        useShortcuts: Bool = true
    ) async throws -> Reminder {
        try await permissionService.ensureRemindersAccess()

        // Step 1: Create basic reminder via EventKit
        let reminderId = try createViaEventKit(
            title: title,
            listName: listName,
            notes: notes,
            url: url,
            dueDate: dueDate,
            priority: priority
        )

        // Step 2: Post-process with advanced features if needed (tags, flagged, parentTitle, url)
        if needsAdvancedProcessing(tags: tags, parentTitle: parentTitle, flagged: flagged, url: url) {
            try await postProcessReminder(
                id: reminderId,
                tags: tags,
                parentTitle: parentTitle,
                flagged: flagged,
                url: url,
                useShortcuts: useShortcuts
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
        clearDue: Bool = false,
        startDate: String? = nil,
        clearStart: Bool = false,
        priority: Int? = nil,
        tags: String? = nil,
        url: String? = nil,
        parentTitle: String? = nil,
        flagged: Bool? = nil,
        useShortcuts: Bool = true
    ) async throws -> Reminder {
        try await permissionService.ensureRemindersAccess()

        // Step 1: Update basic properties via EventKit
        try updateViaEventKit(
            id: id,
            title: title,
            completed: completed,
            notes: notes,
            dueDate: dueDate,
            clearDue: clearDue,
            startDate: startDate,
            clearStart: clearStart,
            priority: priority,
            url: url
        )

        // Step 2: Post-process with advanced features if needed
        if needsAdvancedProcessing(tags: tags, parentTitle: parentTitle, flagged: flagged, url: url) {
            try await postProcessReminder(
                id: id,
                tags: tags,
                parentTitle: parentTitle,
                flagged: flagged,
                url: url,
                useShortcuts: useShortcuts
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
    private func needsAdvancedProcessing(tags: String?, parentTitle: String?, flagged: Bool?, url: String?) -> Bool {
        return tags != nil || parentTitle != nil || flagged != nil || url != nil
    }

    /// Fetch a reminder by ID
    private func fetchReminder(id: String) throws -> Reminder {
        guard let ekReminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventCLIError.notFound("Reminder with ID '\(id)' not found")
        }
        return Reminder(from: ekReminder)
    }

    /// Post-process reminder with advanced features via Shortcut
    private func postProcessReminder(
        id: String,
        tags: String?,
        parentTitle: String?,
        flagged: Bool?,
        url: String?,
        useShortcuts: Bool
    ) async throws {
        // Get reminder details for shortcut
        guard let ekReminder = eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw EventCLIError.notFound("Reminder with ID '\(id)' not found")
        }

        let title = ekReminder.title ?? ""
        let listName = ekReminder.calendar?.title ?? "Reminders"

        // If shortcuts are disabled, skip entirely
        if !useShortcuts {
            if tags != nil || parentTitle != nil || flagged != nil || url != nil {
                print("Note: Advanced fields (tags, flagged, parentTitle, url) require Shortcut integration.")
                print("Use without --no-shortcuts to enable.")
            }
            // Fallback for URL if shortcuts are disabled
            if let url = url, let validURL = URL(string: url) {
                ekReminder.url = validURL
                try eventStore.save(ekReminder, commit: true)
            }
            return
        }

        let shortcutsService = ShortcutsService()
        let shortcutName = "AdvancedReminderEdit"

        // Check if shortcut is installed
        let isShortcutInstalled: Bool
        do {
            isShortcutInstalled = try await shortcutsService.isShortcutInstalled(name: shortcutName)
        } catch {
            print("Note: Could not check for shortcut. Advanced features disabled.")
            // Fallback for URL
            if let url = url, let validURL = URL(string: url) {
                ekReminder.url = validURL
                try eventStore.save(ekReminder, commit: true)
            }
            return
        }

        // Convert flagged to "Yes"/"No" string for shortcut
        let flaggedString: String? = flagged == true ? "Yes" : (flagged == false ? "No" : nil)

        if isShortcutInstalled {
            let payload = AdvancedReminderEditPayload(
                title: title,
                list: listName,
                tags: tags,
                url: url,
                parentTitle: parentTitle,
                isFlagged: flaggedString
            )

            do {
                _ = try await shortcutsService.runShortcut(name: shortcutName, input: payload)
                return
            } catch {
                print("Note: Shortcut execution failed. Advanced features not set.")
                // Fallback for URL
                if let url = url, let validURL = URL(string: url) {
                    ekReminder.url = validURL
                    try eventStore.save(ekReminder, commit: true)
                }
                return
            }
        }

        // Shortcut not available - show info message
        print("Note: AdvancedReminderEdit shortcut not found.")
        print("Install it at: https://www.icloud.com/shortcuts/b578334075754da9ba6e50b501515808")
        print("Without it, only basic reminder fields (title, notes, dueDate, priority) can be set.")
        // Fallback for URL
        if let url = url, let validURL = URL(string: url) {
            ekReminder.url = validURL
            try eventStore.save(ekReminder, commit: true)
        }
    }

    /// Create reminder via EventKit (basic properties only)
    private func createViaEventKit(
        title: String,
        listName: String?,
        notes: String?,
        url: String?,
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

        // Set notes (basic notes, no tags/subtasks)
        if let notes = notes, !notes.isEmpty {
            ekReminder.notes = notes
        }

        // We no longer set URL here since it's handled by Shortcuts for better compatibility
        // The fallback is handled in postProcessReminder if shortcuts are disabled
        // Let EventKit create the item first, URL will be added later

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
        clearDue: Bool,
        startDate: String?,
        clearStart: Bool,
        priority: Int?,
        url: String?
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
            ekReminder.notes = notes
        }

        // We no longer set URL here since it's handled by Shortcuts for better compatibility
        // The fallback is handled in postProcessReminder if shortcuts are disabled
        // Let EventKit create the item first, URL will be added later

        if clearDue {
            ekReminder.dueDateComponents = nil
        } else if let dueDateString = dueDate {
            let date = try Date.validated(dateTimeString: dueDateString)
            let components = DateComponentsBuilder.build(from: date, timeZone: .current)
            ekReminder.dueDateComponents = components
        }

        if clearStart {
            ekReminder.startDateComponents = nil
        } else if let startDateString = startDate {
            let date = try Date.validated(dateTimeString: startDateString)
            let components = DateComponentsBuilder.build(from: date, timeZone: .current)
            ekReminder.startDateComponents = components
        }

        if let priority = priority {
            ekReminder.priority = priority
        }

        try eventStore.save(ekReminder, commit: true)
    }
}

import EventKit
import Foundation

// MARK: - Subtask Service

actor SubtaskService {
    private let eventStore = EKEventStore()
    private let permissionService = PermissionService()

    /// Fetch subtasks for a reminder
    func fetchSubtasks(reminderId: String) async throws -> [Subtask] {
        try await permissionService.ensureRemindersAccess()

        guard let ekReminder = eventStore.calendarItem(withIdentifier: reminderId) as? EKReminder else {
            throw EventCLIError.notFound("Reminder with ID '\(reminderId)' not found")
        }

        return NotesParser.parse(ekReminder.notes).subtasks
    }

    /// Create a new subtask
    func createSubtask(reminderId: String, title: String) async throws -> Subtask {
        try await permissionService.ensureRemindersAccess()

        guard let ekReminder = eventStore.calendarItem(withIdentifier: reminderId) as? EKReminder else {
            throw EventCLIError.notFound("Reminder with ID '\(reminderId)' not found")
        }

        var parsed = NotesParser.parse(ekReminder.notes)
        let newSubtask = Subtask(
            id: NotesParser.generateSubtaskId(),
            title: title,
            isCompleted: false
        )
        parsed.subtasks.append(newSubtask)
        ekReminder.notes = NotesParser.serialize(parsed)

        try eventStore.save(ekReminder, commit: true)
        return newSubtask
    }

    /// Toggle subtask completion
    func toggleSubtask(reminderId: String, subtaskId: String) async throws -> Subtask {
        try await permissionService.ensureRemindersAccess()

        guard let ekReminder = eventStore.calendarItem(withIdentifier: reminderId) as? EKReminder else {
            throw EventCLIError.notFound("Reminder with ID '\(reminderId)' not found")
        }

        var parsed = NotesParser.parse(ekReminder.notes)
        guard let index = parsed.subtasks.firstIndex(where: { $0.id == subtaskId }) else {
            throw EventCLIError.notFound("Subtask with ID '\(subtaskId)' not found")
        }

        parsed.subtasks[index] = Subtask(
            id: parsed.subtasks[index].id,
            title: parsed.subtasks[index].title,
            isCompleted: !parsed.subtasks[index].isCompleted
        )
        ekReminder.notes = NotesParser.serialize(parsed)

        try eventStore.save(ekReminder, commit: true)
        return parsed.subtasks[index]
    }

    /// Delete a subtask
    func deleteSubtask(reminderId: String, subtaskId: String) async throws {
        try await permissionService.ensureRemindersAccess()

        guard let ekReminder = eventStore.calendarItem(withIdentifier: reminderId) as? EKReminder else {
            throw EventCLIError.notFound("Reminder with ID '\(reminderId)' not found")
        }

        var parsed = NotesParser.parse(ekReminder.notes)
        parsed.subtasks.removeAll { $0.id == subtaskId }
        ekReminder.notes = NotesParser.serialize(parsed)

        try eventStore.save(ekReminder, commit: true)
    }

    /// Reorder subtasks
    func reorderSubtasks(reminderId: String, order: [String]) async throws -> [Subtask] {
        try await permissionService.ensureRemindersAccess()

        guard let ekReminder = eventStore.calendarItem(withIdentifier: reminderId) as? EKReminder else {
            throw EventCLIError.notFound("Reminder with ID '\(reminderId)' not found")
        }

        var parsed = NotesParser.parse(ekReminder.notes)
        let subtaskDict = Dictionary(uniqueKeysWithValues: parsed.subtasks.map { ($0.id, $0) })
        parsed.subtasks = order.compactMap { subtaskDict[$0] }
        ekReminder.notes = NotesParser.serialize(parsed)

        try eventStore.save(ekReminder, commit: true)
        return parsed.subtasks
    }
}

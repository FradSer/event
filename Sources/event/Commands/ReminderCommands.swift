import ArgumentParser
import Foundation

// MARK: - Reminder Commands

struct ReminderCommands: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reminders",
        abstract: "Manage Apple Reminders (tasks, lists, subtasks)",
        subcommands: [List.self, Create.self, Update.self, Delete.self, ListCommands.self]
    )

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List reminders"
        )

        @Option(name: .shortAndLong, help: "Filter by list name")
        var list: String?

        @Flag(name: .shortAndLong, help: "Include completed reminders")
        var completed = false

        @Flag(help: "Output in JSON format")
        var json = false

        func run() async throws {
            let service = ReminderService()
            let reminders = try await service.fetchReminders(
                listName: list,
                showCompleted: completed
            )

            let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
            print(formatter.format(reminders))
        }
    }

    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a new reminder"
        )

        @Option(name: .shortAndLong, help: "Reminder title")
        var title: String

        @Option(name: .shortAndLong, help: "List name")
        var list: String?

        @Option(name: .shortAndLong, help: "Due date (yyyy-MM-dd HH:mm:ss)")
        var due: String?

        @Option(name: .shortAndLong, help: "Priority (0-9)")
        var priority: Int?

        @Option(name: .shortAndLong, help: "Notes")
        var notes: String?

        @Option(name: .shortAndLong, help: "URL")
        var url: String?

        @Option(help: "Comma-separated tags")
        var tags: String?

        @Option(help: "Parent reminder title (for creating subtasks via Shortcut)")
        var parentTitle: String?

        @Flag(help: "Mark as flagged")
        var flagged = false

        @Flag(name: .long, help: "Disable Shortcut integration")
        var noShortcuts = false

        @Flag(help: "Output in JSON format")
        var json = false

        func run() async throws {
            let service = ReminderService()

            let reminder = try await service.createReminder(
                title: title,
                listName: list,
                notes: notes,
                url: url,
                dueDate: due,
                priority: priority,
                tags: tags,
                parentTitle: parentTitle,
                flagged: flagged ? true : nil,
                useShortcuts: !noShortcuts
            )

            let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
            print(formatter.format(reminder))
        }
    }

    struct Update: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Update an existing reminder"
        )

        @Option(name: .shortAndLong, help: "Reminder ID")
        var id: String

        @Option(name: .shortAndLong, help: "New title")
        var title: String?

        @Flag(name: .shortAndLong, help: "Mark as completed")
        var completed = false

        @Option(name: .shortAndLong, help: "New priority (0-9)")
        var priority: Int?

        @Option(name: .shortAndLong, help: "New due date (yyyy-MM-dd HH:mm:ss)")
        var due: String?

        @Option(name: .shortAndLong, help: "New notes")
        var notes: String?

        @Option(help: "Comma-separated tags")
        var tags: String?

        @Option(name: .shortAndLong, help: "New URL")
        var url: String?

        @Option(help: "Parent reminder title (for converting to subtask)")
        var parentTitle: String?

        @Flag(help: "Mark as flagged")
        var flagged = false

        @Flag(name: .long, help: "Disable Shortcut integration")
        var noShortcuts = false

        @Flag(help: "Output in JSON format")
        var json = false

        func run() async throws {
            let service = ReminderService()

            let reminder = try await service.updateReminder(
                id: id,
                title: title,
                completed: completed ? true : nil,
                notes: notes,
                dueDate: due,
                priority: priority,
                tags: tags,
                url: url,
                parentTitle: parentTitle,
                flagged: flagged ? true : nil,
                useShortcuts: !noShortcuts
            )

            let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
            print(formatter.format(reminder))
        }
    }

    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Delete a reminder"
        )

        @Option(name: .shortAndLong, help: "Reminder ID")
        var id: String

        func run() async throws {
            let service = ReminderService()
            try await service.deleteReminder(id: id)
            print("Reminder deleted successfully")
        }
    }
}

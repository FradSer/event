import ArgumentParser
import Foundation

// MARK: - Subtask Commands

struct SubtaskCommands: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "subtasks",
        abstract: "Manage reminder subtasks",
        subcommands: [List.self, Create.self, Toggle.self, Delete.self, Reorder.self]
    )

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List subtasks for a reminder"
        )

        @Option(name: .shortAndLong, help: "Reminder ID")
        var reminderId: String

        @Flag(help: "Output in JSON format")
        var json = false

        func run() async throws {
            let service = SubtaskService()
            let subtasks = try await service.fetchSubtasks(reminderId: reminderId)

            let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
            print(formatter.format(subtasks))
        }
    }

    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a new subtask"
        )

        @Option(name: .shortAndLong, help: "Reminder ID")
        var reminderId: String

        @Option(name: .shortAndLong, help: "Subtask title")
        var title: String

        @Flag(help: "Output in JSON format")
        var json = false

        func run() async throws {
            let service = SubtaskService()
            let subtask = try await service.createSubtask(reminderId: reminderId, title: title)

            let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
            print(formatter.format(subtask))
        }
    }

    struct Toggle: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Toggle subtask completion status"
        )

        @Option(name: .shortAndLong, help: "Reminder ID")
        var reminderId: String

        @Option(name: .shortAndLong, help: "Subtask ID")
        var subtaskId: String

        @Flag(help: "Output in JSON format")
        var json = false

        func run() async throws {
            let service = SubtaskService()
            let subtask = try await service.toggleSubtask(reminderId: reminderId, subtaskId: subtaskId)

            let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
            print(formatter.format(subtask))
        }
    }

    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Delete a subtask"
        )

        @Option(name: .shortAndLong, help: "Reminder ID")
        var reminderId: String

        @Option(name: .shortAndLong, help: "Subtask ID")
        var subtaskId: String

        func run() async throws {
            let service = SubtaskService()
            try await service.deleteSubtask(reminderId: reminderId, subtaskId: subtaskId)
            print("Subtask deleted successfully")
        }
    }

    struct Reorder: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Reorder subtasks"
        )

        @Option(name: .shortAndLong, help: "Reminder ID")
        var reminderId: String

        @Option(name: .shortAndLong, help: "Comma-separated subtask IDs in new order")
        var order: String

        @Flag(help: "Output in JSON format")
        var json = false

        func run() async throws {
            let service = SubtaskService()
            let orderArray = order.components(separatedBy: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            let subtasks = try await service.reorderSubtasks(reminderId: reminderId, order: orderArray)

            let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
            print(formatter.format(subtasks))
        }
    }
}

import ArgumentParser
import Foundation

// MARK: - List Commands

struct ListCommands: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lists",
        abstract: "Manage reminder lists",
        subcommands: [List.self, Create.self, Update.self, Delete.self]
    )

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List all reminder lists"
        )

        @Flag(help: "Output in JSON format")
        var json = false

        func run() async throws {
            let service = ListService()
            let lists = try await service.fetchLists()

            let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
            print(formatter.format(lists))
        }
    }

    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a new reminder list"
        )

        @Option(name: .shortAndLong, help: "List name")
        var name: String

        @Flag(help: "Output in JSON format")
        var json = false

        func run() async throws {
            let service = ListService()
            let list = try await service.createList(name: name)

            let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
            print(formatter.format(list))
        }
    }

    struct Update: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Update an existing reminder list"
        )

        @Option(name: .shortAndLong, help: "List ID")
        var id: String

        @Option(name: .shortAndLong, help: "New list name")
        var name: String

        @Flag(help: "Output in JSON format")
        var json = false

        func run() async throws {
            let service = ListService()
            let list = try await service.updateList(id: id, name: name)

            let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
            print(formatter.format(list))
        }
    }

    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Delete a reminder list"
        )

        @Option(name: .shortAndLong, help: "List ID")
        var id: String

        func run() async throws {
            let service = ListService()
            try await service.deleteList(id: id)
            print("List deleted successfully")
        }
    }
}

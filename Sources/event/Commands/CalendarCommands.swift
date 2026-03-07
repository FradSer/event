import ArgumentParser
import Foundation

// MARK: - Calendar Commands

struct CalendarCommands: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "calendar",
        abstract: "Manage Apple Calendar (events, calendars)",
        subcommands: [List.self, Create.self, Update.self, Delete.self]
    )

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "List calendar events"
        )

        @Option(name: .shortAndLong, help: "Start date (yyyy-MM-dd)")
        var start: String?

        @Option(name: .shortAndLong, help: "End date (yyyy-MM-dd)")
        var end: String?

        @Option(name: .shortAndLong, help: "Filter by calendar name")
        var calendar: String?

        @Flag(help: "Output in JSON format")
        var json = false

        func run() async throws {
            let service = CalendarService()
            let events = try await service.fetchEvents(
                startDate: start,
                endDate: end,
                calendarName: calendar
            )

            let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
            print(formatter.format(events))
        }
    }

    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Create a new calendar event"
        )

        @Option(name: .shortAndLong, help: "Event title")
        var title: String

        @Option(
            name: .shortAndLong,
            help: "Start date (yyyy-MM-dd for all-day, yyyy-MM-dd HH:mm:ss for timed)"
        )
        var start: String

        @Option(
            name: .shortAndLong, help: "End date (yyyy-MM-dd for all-day, yyyy-MM-dd HH:mm:ss for timed)"
        )
        var end: String

        @Option(name: .shortAndLong, help: "Calendar name")
        var calendar: String?

        @Option(name: .shortAndLong, help: "Event location")
        var location: String?

        @Option(name: .shortAndLong, help: "Event notes")
        var notes: String?

        @Flag(help: "Output in JSON format")
        var json = false

        func run() async throws {
            let service = CalendarService()
            let event = try await service.createEvent(
                title: title,
                startDate: start,
                endDate: end,
                calendarName: calendar,
                location: location,
                notes: notes
            )

            let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
            print(formatter.format(event))
        }
    }

    struct Update: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Update an existing calendar event"
        )

        @Option(name: .shortAndLong, help: "Event ID")
        var id: String

        @Option(name: .shortAndLong, help: "New title")
        var title: String?

        @Option(name: .shortAndLong, help: "New start datetime (yyyy-MM-dd HH:mm:ss)")
        var start: String?

        @Option(name: .shortAndLong, help: "New end datetime (yyyy-MM-dd HH:mm:ss)")
        var end: String?

        @Option(name: .shortAndLong, help: "New location")
        var location: String?

        @Option(name: .shortAndLong, help: "New notes")
        var notes: String?

        @Flag(help: "Output in JSON format")
        var json = false

        func run() async throws {
            let service = CalendarService()
            let event = try await service.updateEvent(
                id: id,
                title: title,
                startDate: start,
                endDate: end,
                location: location,
                notes: notes
            )

            let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
            print(formatter.format(event))
        }
    }

    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Delete a calendar event"
        )

        @Option(name: .shortAndLong, help: "Event ID")
        var id: String

        @Option(help: "Delete span: this, future, or all")
        var span: String = "this"

        func run() async throws {
            let service = CalendarService()
            try await service.deleteEvent(id: id, span: span)
            print("Event deleted successfully")
        }
    }
}

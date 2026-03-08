import ArgumentParser
import Foundation

@main
struct EventCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "event",
        abstract: "CLI tool for managing Apple Reminders and Calendar on macOS",
        version: "0.1.1",
        subcommands: [
            ReminderCommands.self,
            CalendarCommands.self,
        ]
    )

    @Flag(name: .shortAndLong, help: "Disable Shortcut integration")
    var noShortcuts: Bool = false
}

import ArgumentParser
import EventModels
import Foundation

@main
struct EventCLI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "event",
    abstract: "CLI tool for managing Apple Reminders and Calendar on macOS",
    version: "0.2.0",
    subcommands: [
      ReminderCommands.self,
      CalendarCommands.self,
      SyncCommands.self,
    ]
  )

  @Flag(name: .shortAndLong, help: "Disable Shortcut integration")
  var noShortcuts: Bool = false
}

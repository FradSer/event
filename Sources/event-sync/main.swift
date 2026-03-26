import ArgumentParser
import EventModels
import Foundation

@main
struct EventSyncCLI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "event-sync",
    abstract: "Cross-platform CLI for reading/writing event data via Cloudflare D1",
    version: "0.1.0",
    subcommands: [
      RemindersCommands.self,
      CalendarCommands.self,
      SyncCommands.self,
    ]
  )
}

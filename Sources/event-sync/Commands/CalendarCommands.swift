import ArgumentParser
import EventModels
import EventSync
import Foundation

// MARK: - Calendar Commands (Linux / D1-only)

struct CalendarCommands: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "calendar",
    abstract: "Read calendar events from Cloudflare D1",
    subcommands: [List.self]
  )

  // MARK: - List

  struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "List calendar events from D1"
    )

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      let config = try SyncConfigStore.load()
      let client = D1SyncClient(config: config)
      do {
        var allEvents: [CalendarEvent] = []
        var cursor: String? = nil
        var hasMore = true

        while hasMore {
          let response = try await client.pullEvents(cursor: cursor)
          allEvents += response.items.filter { !$0.deleted }.map { $0.data }
          cursor = response.cursor
          hasMore = response.hasMore
        }

        let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
        print(formatter.format(allEvents))
        try await client.shutdown()
      } catch {
        try? await client.shutdown()
        throw error
      }
    }
  }
}

import ArgumentParser
import EventModels
import EventSync
import Foundation

// MARK: - Sync Calendar Commands (D1-direct)

/// Reads calendar events directly from Cloudflare D1, bypassing local EventKit.
/// Distinct from `event calendar`, which operates on local Apple data.
struct SyncCalendarCommands: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "calendar",
    abstract: "Read calendar events directly from Cloudflare D1",
    subcommands: [List.self]
  )

  // MARK: - List

  struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "List calendar events stored in Cloudflare D1"
    )

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      let config = try SyncConfigStore.load()
      let client = D1SyncClient(config: config)
      do {
        let events = try await client.pullAllEvents()
        let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
        print(formatter.format(events))
        try await client.shutdown()
      } catch {
        try? await client.shutdown()
        throw error
      }
    }
  }
}

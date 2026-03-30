import ArgumentParser
import EventModels
import EventSync
import Foundation

// MARK: - Reminders Commands (Linux / D1-only)

struct RemindersCommands: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "reminders",
    abstract: "Manage reminders via Cloudflare D1",
    subcommands: [List.self, Create.self]
  )

  // MARK: - List

  struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "List reminders from D1"
    )

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      let config = try SyncConfigStore.load()
      let client = D1SyncClient(config: config)
      do {
        var allReminders: [Reminder] = []
        var cursor: String? = nil
        var hasMore = true

        while hasMore {
          let response = try await client.pullReminders(cursor: cursor)
          allReminders += response.items.filter { !$0.deleted }.map { $0.data }
          cursor = response.cursor
          hasMore = response.hasMore
        }

        let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
        print(formatter.format(allReminders))
        try await client.shutdown()
      } catch {
        try? await client.shutdown()
        throw error
      }
    }
  }

  // MARK: - Create

  struct Create: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Create a reminder in D1 (Linux-originated)"
    )

    @Option(name: .shortAndLong, help: "Reminder title")
    var title: String

    @Option(name: .shortAndLong, help: "List name")
    var list: String = "Reminders"

    @Option(name: .shortAndLong, help: "Notes")
    var notes: String?

    @Option(name: .shortAndLong, help: "Due date (yyyy-MM-dd HH:mm:ss)")
    var due: String?

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      // Validate due date if provided
      if let due = due {
        _ = try Date.validated(dateTimeString: due)
      }

      let config = try SyncConfigStore.load()
      let client = D1SyncClient(config: config)
      do {
        let now = DateFormatter.eventISO8601.string(from: Date())
        let reminder = Reminder(
          id: UUID().uuidString,
          title: title,
          isCompleted: false,
          isFlagged: false,
          list: list,
          notes: notes,
          url: nil,
          location: nil,
          timeZone: TimeZone.current.identifier,
          dueDate: due,
          startDate: nil,
          completionDate: nil,
          creationDate: now,
          lastModifiedDate: now,
          externalId: nil,
          priority: 0,
          alarms: nil,
          recurrenceRules: nil,
          locationTrigger: nil
        )

        let result = try await client.pushReminders([reminder])
        if result.synced > 0 {
          let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
          print(formatter.format(reminder))
        } else {
          print("Warning: reminder was skipped (server may have a newer version)")
        }
        try await client.shutdown()
      } catch {
        try? await client.shutdown()
        throw error
      }
    }
  }
}

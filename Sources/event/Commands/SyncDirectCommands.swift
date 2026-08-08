import AppleSyncKit
import ArgumentParser
import EventModels
import EventSync
import Foundation

// MARK: - Direct D1 Access

/// Advanced subcommands that read and write Cloudflare D1 directly, bypassing
/// local EventKit. Sensitive fields are decrypted on read and encrypted on write
/// using EVENT_ENCRYPTION_KEY, so the direct path matches the main `event sync`.
private enum DirectAccess {
  static func withReminderService<R>(
    _ body: @Sendable (CloudflareReminderService) async throws -> R
  ) async throws -> R {
    let config = try SyncConfigStore.load()
    return try await D1SyncClient.withClient(config: config) { client in
      let encryptor = try EventEncryptor.fromEnvironment()
      let service = CloudflareReminderService(client: client, encryptor: encryptor)
      return try await body(service)
    }
  }

  static func withCalendarService<R>(
    _ body: @Sendable (CloudflareCalendarService) async throws -> R
  ) async throws -> R {
    let config = try SyncConfigStore.load()
    return try await D1SyncClient.withClient(config: config) { client in
      let encryptor = try EventEncryptor.fromEnvironment()
      let service = CloudflareCalendarService(client: client, encryptor: encryptor)
      return try await body(service)
    }
  }

  static func formatter(json: Bool) -> OutputFormatter {
    json ? JSONFormatter() : MarkdownFormatter()
  }
}

// MARK: - Sync Reminders Commands (D1-direct)

/// Reads and writes reminders directly in Cloudflare D1, bypassing local EventKit.
/// Distinct from `event reminders`, which operates on local Apple data.
struct SyncRemindersCommands: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "reminders",
    abstract: "Read or write reminders directly in Cloudflare D1",
    subcommands: [List.self, Create.self]
  )

  struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "List reminders stored in Cloudflare D1"
    )

    @Option(name: .shortAndLong, help: "Filter by list name")
    var list: String?

    @Flag(name: .shortAndLong, help: "Include completed reminders")
    var completed = false

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      let reminders = try await DirectAccess.withReminderService {
        try await $0.fetchReminders(listName: list, showCompleted: completed)
      }
      print(DirectAccess.formatter(json: json).format(reminders))
    }
  }

  struct Create: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Create a reminder directly in Cloudflare D1"
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
      if let due = due {
        _ = try Date.validated(dateTimeString: due)
      }
      let reminder = try await DirectAccess.withReminderService {
        try await $0.createReminder(
          CreateReminderParams(title: title, listName: list, notes: notes, dueDate: due))
      }
      print(DirectAccess.formatter(json: json).format(reminder))
    }
  }
}

// MARK: - Sync Calendar Commands (D1-direct)

/// Reads calendar events directly from Cloudflare D1, bypassing local EventKit.
/// Distinct from `event calendar`, which operates on local Apple data.
struct SyncCalendarCommands: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "calendar",
    abstract: "Read calendar events directly from Cloudflare D1",
    subcommands: [List.self]
  )

  struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "List calendar events stored in Cloudflare D1"
    )

    @Option(name: .shortAndLong, help: "Filter by calendar name")
    var calendar: String?

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      // A wide range returns every event; the service decrypts on read.
      let events = try await DirectAccess.withCalendarService {
        try await $0.fetchEvents(start: "0000-01-01", end: "9999-12-31", calendarName: calendar)
      }
      print(DirectAccess.formatter(json: json).format(events))
    }
  }
}

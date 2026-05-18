import ArgumentParser
import EventCommands
import EventModels
import Foundation

// MARK: - Sync Entity Type

enum SyncEntityType: String, ExpressibleByArgument, CaseIterable {
  case reminders
  case calendar
  case lists
  case all

  static let fullPullOrder: [SyncEntityType] = [.lists, .reminders, .calendar]
}

// MARK: - Sync Commands

struct SyncCommands: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sync",
    abstract: "Sync event data with Cloudflare D1",
    subcommands: [Push.self, Pull.self, SyncConfigCommand.self, SyncStatusCommand.self]
  )

  // MARK: - Push

  struct Push: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Push local data to Cloudflare D1",
      discussion: """
        Calendar events are synced only within a window from one year in the \
        past to two years ahead; events outside this window are not synced. \
        Reminders and reminder lists are not windowed.
        """
    )

    @Option(help: "Type to sync: reminders, calendar, lists, all")
    var type: SyncEntityType = .all

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      let lockFd = try SyncConfigStore.acquireLock()
      defer { SyncConfigStore.releaseLock(lockFd) }

      let config = try SyncConfigStore.load()
      let service = SyncService(config: config)
      do {
        var output: [String: PushResult] = [:]
        switch type {
        case .reminders:
          output["reminders"] = try await service.pushReminders()
        case .calendar:
          output["calendarEvents"] = try await service.pushEvents()
        case .lists:
          output["reminderLists"] = try await service.pushLists()
        case .all:
          output["reminders"] = try await service.pushReminders()
          output["calendarEvents"] = try await service.pushEvents()
          output["reminderLists"] = try await service.pushLists()
        }
        try await service.shutdown()
        printPushOutput(output)
      } catch {
        try? await service.shutdown()
        throw error
      }
    }

    private func printPushOutput(_ output: [String: PushResult]) {
      if json {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(output),
          let str = String(data: data, encoding: .utf8)
        {
          print(str)
        }
      } else {
        let labels: [(String, String)] = [
          ("reminders", "Reminders"),
          ("calendarEvents", "Calendar events"),
          ("reminderLists", "Reminder lists"),
        ]
        for (key, label) in labels {
          if let result = output[key] {
            print("\(label): synced \(result.synced), skipped \(result.skipped)")
          }
        }
      }
    }
  }

  // MARK: - Pull

  struct Pull: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Pull data from Cloudflare D1",
      discussion: """
        Calendar events are synced only within a window from one year in the \
        past to two years ahead. Conflicts resolve by last-write-wins: a pull \
        never overwrites a local copy modified more recently than the \
        server's version, and that copy is pushed on the next sync.
        """
    )

    @Option(help: "Type to sync: reminders, calendar, lists, all")
    var type: SyncEntityType = .all

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      let lockFd = try SyncConfigStore.acquireLock()
      defer { SyncConfigStore.releaseLock(lockFd) }

      let config = try SyncConfigStore.load()
      let service = SyncService(config: config)
      do {
        var output: [String: PullSummary] = [:]
        switch type {
        case .reminders:
          output["reminders"] = try await service.pullReminders()
        case .calendar:
          output["calendarEvents"] = try await service.pullEvents()
        case .lists:
          output["reminderLists"] = try await service.pullLists()
        case .all:
          for entity in SyncEntityType.fullPullOrder {
            switch entity {
            case .lists:
              output["reminderLists"] = try await service.pullLists()
            case .reminders:
              output["reminders"] = try await service.pullReminders()
            case .calendar:
              output["calendarEvents"] = try await service.pullEvents()
            case .all:
              break
            }
          }
        }
        try await service.shutdown()
        printPullOutput(output)
      } catch {
        try? await service.shutdown()
        throw error
      }
    }

    private func printPullOutput(_ output: [String: PullSummary]) {
      if json {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(output),
          let str = String(data: data, encoding: .utf8)
        {
          print(str)
        }
      } else {
        let labels: [(String, String)] = [
          ("reminderLists", "Reminder lists"),
          ("reminders", "Reminders"),
          ("calendarEvents", "Calendar events"),
        ]
        for (key, label) in labels {
          if let summary = output[key] {
            print(
              "\(label): pulled \(summary.pulled), deleted \(summary.deleted), "
                + "skipped \(summary.skipped)")
          }
        }
      }
    }
  }
}

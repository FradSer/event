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
      abstract: "Push local data to Cloudflare D1"
    )

    @Option(help: "Type to sync: reminders, calendar, lists, all")
    var type: SyncEntityType = .all

    func run() async throws {
      let config = try SyncConfigStore.load()
      let service = SyncService(config: config)
      do {
        switch type {
        case .reminders:
          let result = try await service.pushReminders()
          print("Reminders: synced \(result.synced), skipped \(result.skipped)")
        case .calendar:
          let result = try await service.pushEvents()
          print("Calendar events: synced \(result.synced), skipped \(result.skipped)")
        case .lists:
          let result = try await service.pushLists()
          print("Reminder lists: synced \(result.synced), skipped \(result.skipped)")
        case .all:
          let r = try await service.pushReminders()
          let c = try await service.pushEvents()
          let l = try await service.pushLists()
          print("Reminders: synced \(r.synced), skipped \(r.skipped)")
          print("Calendar events: synced \(c.synced), skipped \(c.skipped)")
          print("Reminder lists: synced \(l.synced), skipped \(l.skipped)")
        }
        try await service.shutdown()
      } catch {
        try? await service.shutdown()
        throw error
      }
    }
  }

  // MARK: - Pull

  struct Pull: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Pull data from Cloudflare D1"
    )

    @Option(help: "Type to sync: reminders, calendar, lists, all")
    var type: SyncEntityType = .all

    func run() async throws {
      let config = try SyncConfigStore.load()
      let service = SyncService(config: config)
      do {
        switch type {
        case .reminders:
          let summary = try await service.pullReminders()
          printPullSummary("Reminders", summary: summary)
        case .calendar:
          let summary = try await service.pullEvents()
          printPullSummary("Calendar events", summary: summary)
        case .lists:
          let summary = try await service.pullLists()
          printPullSummary("Reminder lists", summary: summary)
        case .all:
          let r = try await service.pullReminders()
          let c = try await service.pullEvents()
          let l = try await service.pullLists()
          printPullSummary("Reminders", summary: r)
          printPullSummary("Calendar events", summary: c)
          printPullSummary("Reminder lists", summary: l)
        }
        try await service.shutdown()
      } catch {
        try? await service.shutdown()
        throw error
      }
    }

    private func printPullSummary(_ label: String, summary: PullSummary) {
      print("\(label): pulled \(summary.pulled), deleted \(summary.deleted)")
    }
  }
}

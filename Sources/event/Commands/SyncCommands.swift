import AppleSyncKit
import ArgumentParser
import EventCommands
import EventModels
import EventSync
import Foundation

// MARK: - Sync Entity Type

enum SyncEntityType: String, ExpressibleByArgument, CaseIterable {
  case reminders
  case calendar
  case lists
  case all

  static let fullPullOrder: [SyncEntityType] = [.lists, .reminders, .calendar]

  var syncEntities: [SyncEntity] {
    switch self {
    case .reminders: [.reminders]
    case .calendar: [.calendarEvents]
    case .lists: [.reminderLists]
    case .all: [.reminderLists, .reminders, .calendarEvents]
    }
  }
}

// MARK: - Sync Commands

struct SyncCommands: AsyncParsableCommand {
  // `sync daemon` is macOS-only (launchd); keep it out of the command list on
  // other platforms so the binary still compiles there.
  private static let subcommands: [any AsyncParsableCommand.Type] = {
    #if os(macOS)
      return [
        FullSync.self, Push.self, Pull.self, SyncConfigCommand.self, SyncStatusCommand.self,
        SyncDaemonCommand.self, SyncRemindersCommands.self, SyncCalendarCommands.self,
      ]
    #else
      return [
        FullSync.self, Push.self, Pull.self, SyncConfigCommand.self, SyncStatusCommand.self,
        SyncRemindersCommands.self, SyncCalendarCommands.self,
      ]
    #endif
  }()

  static let configuration = CommandConfiguration(
    commandName: "sync",
    abstract: "Sync event data with Cloudflare D1",
    subcommands: subcommands,
    defaultSubcommand: FullSync.self
  )

  // MARK: - Full Sync (default)

  struct FullSync: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "run",
      abstract: "Run a full bidirectional sync (pull, then push)",
      discussion: """
        This is what bare 'event sync' runs: it pulls remote changes, then \
        pushes local changes in a single locked session. Calendar events sync \
        only within a window from one year in the past to two years ahead. \
        Conflicts resolve by last-write-wins -- a pull never overwrites a local \
        copy modified more recently than the server's version.

        Advanced subcommands (run 'event sync <name> --help'): 'push' and \
        'pull' for one-directional sync; 'config' and 'status' to manage \
        configuration; 'reminders' and 'calendar' to read or write Cloudflare \
        D1 data directly.
        """
    )

    @Option(help: "Type to sync: reminders, calendar, lists, all")
    var type: SyncEntityType = .all

    @Flag(help: "Output in JSON format")
    var json = false

    @Flag(help: .hidden)
    var daemon = false

    func run() async throws {
      let service = try await BackendFactory.makeSyncService()
      do {
        let result = try await service.fullSync(entities: type.syncEntities)
        try await service.shutdown()
        printFullSyncOutput(pull: result.pull, push: result.push, json: json)
        if daemon {
          recordLastRun(error: nil, pull: result.pull, push: result.push)
        }
      } catch SyncError.alreadyRunning where daemon {
        try? await service.shutdown()
        print("Another sync is in progress, skipping.")
      } catch {
        try? await service.shutdown()
        if daemon {
          recordLastRun(error: error.localizedDescription, pull: [:], push: [:])
        }
        throw error
      }
    }

    /// Writes `~/.config/event-sync/last-run.json` for `sync daemon status`.
    private func recordLastRun(
      error: String?,
      pull: [String: PullSummary],
      push: [String: PushResult]
    ) {
      var summary = pullLines(pull)
      summary.append(contentsOf: pushLines(push))
      let lastRun = SyncLastRun(
        finishedAt: Date(), succeeded: error == nil, error: error, summary: summary)
      try? SyncConfigStore.saveLastRun(lastRun)
    }
  }

  // MARK: - Push

  struct Push: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Push local data to Cloudflare D1 (one-directional)",
      discussion: """
        Advanced one-directional synchronous; bare 'event sync' already pushes. \
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
      let service = try await BackendFactory.makeSyncService()
      do {
        let output = try await service.push(entities: type.syncEntities)
        try await service.shutdown()
        printPushOutput(output, json: json)
      } catch {
        try? await service.shutdown()
        throw error
      }
    }
  }

  // MARK: - Pull

  struct Pull: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Pull data from Cloudflare D1 (one-directional)",
      discussion: """
        Advanced one-directional sync; bare 'event sync' already pulls. \
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
      let service = try await BackendFactory.makeSyncService()
      do {
        let output = try await service.pull(entities: type.syncEntities)
        try await service.shutdown()
        printPullOutput(output, json: json)
      } catch {
        try? await service.shutdown()
        throw error
      }
    }
  }
}

// MARK: - Sync Output

/// Combined JSON document for a full sync.
private struct FullSyncOutput: Encodable {
  let pull: [String: PullSummary]
  let push: [String: PushResult]
}

private func printJSON<T: Encodable>(_ value: T) {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
  if let data = try? encoder.encode(value), let str = String(data: data, encoding: .utf8) {
    print(str)
  }
}

private func pushLines(_ output: [String: PushResult]) -> [String] {
  let labels: [(String, String)] = [
    ("reminders", "Reminders"),
    ("calendarEvents", "Calendar events"),
    ("reminderLists", "Reminder lists"),
  ]
  return labels.compactMap { key, label in
    output[key].map { "\(label): synced \($0.synced), skipped \($0.skipped)" }
  }
}

private func pullLines(_ output: [String: PullSummary]) -> [String] {
  let labels: [(String, String)] = [
    ("reminderLists", "Reminder lists"),
    ("reminders", "Reminders"),
    ("calendarEvents", "Calendar events"),
  ]
  return labels.compactMap { key, label in
    output[key].map {
      "\(label): pulled \($0.pulled), deleted \($0.deleted), skipped \($0.skipped)"
    }
  }
}

func printPushOutput(_ output: [String: PushResult], json: Bool) {
  if json {
    printJSON(output)
  } else {
    for line in pushLines(output) { print(line) }
  }
}

func printPullOutput(_ output: [String: PullSummary], json: Bool) {
  if json {
    printJSON(output)
  } else {
    for line in pullLines(output) { print(line) }
  }
}

func printFullSyncOutput(
  pull: [String: PullSummary], push: [String: PushResult], json: Bool
) {
  if json {
    printJSON(FullSyncOutput(pull: pull, push: push))
  } else {
    print("Pull:")
    for line in pullLines(pull) { print("  \(line)") }
    print("Push:")
    for line in pushLines(push) { print("  \(line)") }
  }
}

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
    subcommands: [
      FullSync.self, Push.self, Pull.self, SyncConfigCommand.self, SyncStatusCommand.self,
    ],
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
        'pull' for one-directional sync, 'config' to save credentials to a \
        file, 'status' to inspect configuration and sync state.
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
        let pullOutput = try await runPull(service, type: type)
        let pushOutput = try await runPush(service, type: type)
        try await service.shutdown()
        printFullSyncOutput(pull: pullOutput, push: pushOutput, json: json)
      } catch {
        try? await service.shutdown()
        throw error
      }
    }
  }

  // MARK: - Push

  struct Push: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Push local data to Cloudflare D1 (one-directional)",
      discussion: """
        Advanced one-directional sync; bare 'event sync' already pushes. \
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
        let output = try await runPush(service, type: type)
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
      let lockFd = try SyncConfigStore.acquireLock()
      defer { SyncConfigStore.releaseLock(lockFd) }

      let config = try SyncConfigStore.load()
      let service = SyncService(config: config)
      do {
        let output = try await runPull(service, type: type)
        try await service.shutdown()
        printPullOutput(output, json: json)
      } catch {
        try? await service.shutdown()
        throw error
      }
    }
  }
}

// MARK: - Sync Sequencing

/// Pushes the requested entity types, returning results keyed by entity.
func runPush(_ service: SyncService, type: SyncEntityType) async throws -> [String: PushResult] {
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
  return output
}

/// Pulls the requested entity types in dependency order, returning results keyed by entity.
func runPull(_ service: SyncService, type: SyncEntityType) async throws -> [String: PullSummary] {
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
  return output
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

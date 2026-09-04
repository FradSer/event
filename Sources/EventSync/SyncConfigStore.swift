import AppleSyncKit
import EventModels
import Foundation

// MARK: - Sync Config Store

/// Thin wrapper over `AppleSyncKit.ConfigStore` configured for event's namespace
/// (`event-sync` / `EVENT`). Sync checkpoints live in the kit's consolidated journal.
public enum SyncConfigStore {
  public static let store = ConfigStore(namespace: "event-sync", prefix: "EVENT")

  public enum EnvKey {
    public static let apiURL = "EVENT_SYNC_API_URL"
    public static let apiToken = "EVENT_SYNC_API_TOKEN"
    public static let deviceId = "EVENT_SYNC_DEVICE_ID"
  }

  public static var configPath: String { store.configPath }

  /// Launchd daemon paths (log + last-run record), under the same namespace.
  public static var daemonLogPath: String {
    baseDirectory.appendingPathComponent("logs/daemon.log").path
  }
  public static var lastRunPath: String {
    baseDirectory.appendingPathComponent("last-run.json").path
  }

  private static var baseDirectory: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".config/event-sync")
  }

  public static func acquireLock() throws -> Int32 { try store.acquireLock() }
  public static func releaseLock(_ fd: Int32) { store.releaseLock(fd) }
  public static func validateAPIURL(_ apiURL: String) throws { try store.validateAPIURL(apiURL) }

  public static func hasEnvironmentConfig(
    _ environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> Bool {
    store.hasEnvironmentConfig(environment)
  }

  public static func load() throws -> SyncConfig {
    try store.loadConfig(
      notFoundMessage: """
        Sync config not found. Either set the environment variables \
        \(EnvKey.apiURL) and \(EnvKey.apiToken) (and optionally \(EnvKey.deviceId)), \
        or run 'event sync config --api-url <URL> --api-token <TOKEN> --device-id <ID>'.
        """)
  }

  public static func save(_ config: SyncConfig) throws { try store.saveConfig(config) }

  public static func loadJournal() throws -> SyncJournalState {
    try store.journal.load()
  }

  public static func loadLastRun() -> SyncLastRun? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: lastRunPath)) else { return nil }
    return try? JSONDecoder().decode(SyncLastRun.self, from: data)
  }

  public static func saveLastRun(_ lastRun: SyncLastRun) throws {
    let url = URL(fileURLWithPath: lastRunPath)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(lastRun).write(to: url, options: .atomic)
    try FileManager.default.setAttributes(
      [.posixPermissions: NSNumber(value: Int16(0o600))], ofItemAtPath: lastRunPath)
  }
}

// MARK: - Sync Last Run

/// Outcome of a daemon-triggered sync, recorded at `last-run.json` and shown
/// by `event sync daemon status`.
public struct SyncLastRun: Codable, Sendable {
  public var finishedAt: Date
  public var succeeded: Bool
  /// Error description when the run failed.
  public var error: String?
  /// Human-readable pull/push summary lines (e.g. "Reminders: pulled 2, ...").
  public var summary: [String]

  public init(finishedAt: Date, succeeded: Bool, error: String?, summary: [String]) {
    self.finishedAt = finishedAt
    self.succeeded = succeeded
    self.error = error
    self.summary = summary
  }
}

// MARK: - Coordinator Wiring

/// Cross-cutting values shared by the macOS and Linux local sync sources.
public enum EventSyncRules {
  /// Recognizes a "not found" thrown by either event's domain layer or the kit.
  public static let isNotFound: @Sendable (Error) -> Bool = { error in
    (error as? SyncNotFound)?.isNotFound ?? false
  }
}

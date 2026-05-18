import Foundation

// MARK: - Sync Config Store

public enum SyncConfigStore {
  private static var baseDirectory: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".config")
      .appendingPathComponent("event-sync")
  }

  /// Acquire an exclusive, non-blocking file lock to prevent concurrent sync operations.
  /// Returns the file descriptor. Call `releaseLock(_:)` when done.
  public static func acquireLock() throws -> Int32 {
    let dir = baseDirectory
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let lockPath = dir.appendingPathComponent(".lock").path
    let fd = open(lockPath, O_CREAT | O_RDWR, 0o600)
    guard fd >= 0 else {
      throw EventCLIError.unknown("Could not create sync lock file")
    }
    guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
      close(fd)
      throw EventCLIError.unknown("Another sync operation is already running")
    }
    return fd
  }

  public static func releaseLock(_ fd: Int32) {
    flock(fd, LOCK_UN)
    close(fd)
  }

  public static var configPath: String {
    baseDirectory.appendingPathComponent("config.json").path
  }

  public static var cursorsPath: String {
    baseDirectory.appendingPathComponent("cursors.json").path
  }

  public static var idMappingPath: String {
    baseDirectory.appendingPathComponent("id-mapping.json").path
  }

  public static var statePath: String {
    baseDirectory.appendingPathComponent("state.json").path
  }

  // MARK: - Config

  /// Environment variable names for sync configuration.
  public enum EnvKey {
    public static let apiURL = "EVENT_SYNC_API_URL"
    public static let apiToken = "EVENT_SYNC_API_TOKEN"
    public static let deviceId = "EVENT_SYNC_DEVICE_ID"
  }

  /// Validates that an API URL uses HTTPS.
  public static func validateAPIURL(_ apiURL: String) throws {
    guard apiURL.lowercased().hasPrefix("https://") else {
      throw EventCLIError.invalidInput("API URL must use HTTPS. Got: \(apiURL)")
    }
  }

  /// Builds a `SyncConfig` from environment variables. Returns `nil` when neither
  /// required variable is set, so the caller can fall back to the config file.
  /// Throws when exactly one required variable is set, or the URL is not HTTPS.
  static func loadFromEnvironment(
    _ environment: [String: String] = ProcessInfo.processInfo.environment
  ) throws -> SyncConfig? {
    func value(_ key: String) -> String? {
      guard let raw = environment[key], !raw.isEmpty else { return nil }
      return raw
    }

    switch (value(EnvKey.apiURL), value(EnvKey.apiToken)) {
    case (nil, nil):
      return nil
    case (let apiURL?, let apiToken?):
      try validateAPIURL(apiURL)
      let deviceId = value(EnvKey.deviceId) ?? ProcessInfo.processInfo.hostName
      return SyncConfig(apiURL: apiURL, apiToken: apiToken, deviceId: deviceId)
    default:
      throw EventCLIError.invalidInput(
        "Both \(EnvKey.apiURL) and \(EnvKey.apiToken) must be set to use "
          + "environment-based sync config.")
    }
  }

  /// Whether both required environment variables are set.
  public static func hasEnvironmentConfig(
    _ environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> Bool {
    func isSet(_ key: String) -> Bool { !(environment[key] ?? "").isEmpty }
    return isSet(EnvKey.apiURL) && isSet(EnvKey.apiToken)
  }

  /// Loads the sync config: environment variables take precedence, then the
  /// config file written by `event sync config`.
  public static func load() throws -> SyncConfig {
    if let envConfig = try loadFromEnvironment() {
      return envConfig
    }
    guard FileManager.default.fileExists(atPath: configPath) else {
      throw EventCLIError.notFound(
        """
        Sync config not found. Either set the environment variables \
        \(EnvKey.apiURL) and \(EnvKey.apiToken) (and optionally \(EnvKey.deviceId)), \
        or run 'event sync config --api-url <URL> --api-token <TOKEN> --device-id <ID>'.
        """
      )
    }
    let data = try Data(contentsOf: URL(fileURLWithPath: configPath))
    return try JSONDecoder().decode(SyncConfig.self, from: data)
  }

  public static func save(_ config: SyncConfig) throws {
    try validateAPIURL(config.apiURL)
    try saveJSON(config, to: configPath)
  }

  // MARK: - Cursors

  public static func loadCursors() -> SyncCursors {
    loadJSON(from: cursorsPath, default: SyncCursors())
  }

  public static func saveCursors(_ cursors: SyncCursors) throws {
    try saveJSON(cursors, to: cursorsPath)
  }

  // MARK: - ID Mapping

  public static func loadIdMapping() -> SyncIdMapping {
    loadJSON(from: idMappingPath, default: SyncIdMapping())
  }

  public static func saveIdMapping(_ mapping: SyncIdMapping) throws {
    try saveJSON(mapping, to: idMappingPath)
  }

  // MARK: - State

  public static func loadState() -> SyncState {
    loadJSON(from: statePath, default: SyncState())
  }

  public static func saveState(_ state: SyncState) throws {
    try saveJSON(state, to: statePath)
  }

  // MARK: - Private Helpers

  private static func saveJSON<T: Encodable>(_ value: T, to path: String) throws {
    let dir = URL(fileURLWithPath: path).deletingLastPathComponent()
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(value)
    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
  }

  private static func loadJSON<T: Decodable>(from path: String, default defaultValue: T) -> T {
    let data: Data
    do {
      data = try Data(contentsOf: URL(fileURLWithPath: path))
    } catch {
      return defaultValue
    }
    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      fputs("Warning: Could not parse \(path): \(error.localizedDescription)\n", stderr)
      return defaultValue
    }
  }
}

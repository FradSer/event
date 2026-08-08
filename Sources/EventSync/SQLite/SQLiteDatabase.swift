import AppleSyncKit
import EventModels
import Foundation
import SQLite

// MARK: - SQLite Database

/// Thread-safe SQLite database manager using SQLite.swift.
public actor SQLiteDatabase {
  // MARK: - Properties

  // SQLite.swift's Connection is Sendable (conformance from AppleSyncKit), so it
  // can be handed out from a nonisolated context.
  private nonisolated let connection: Connection

  /// Default database path at ~/.local/share/event-sync/local.db
  public static var defaultPath: String {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".local")
      .appendingPathComponent("share")
      .appendingPathComponent("event-sync")
      .appendingPathComponent("local.db")
      .path
  }

  // MARK: - Initialization

  private init(connection: Connection) {
    self.connection = connection
  }

  // MARK: - Public Methods

  /// Opens or creates a SQLite database at the specified path.
  /// - Parameter path: Optional path to the database file. Uses default path if nil.
  /// - Returns: A configured SQLiteDatabase instance.
  /// - Throws: EventCLIError if database creation or migration fails.
  public static func open(at path: String? = nil) throws -> SQLiteDatabase {
    let dbPath = path ?? defaultPath

    // Ensure parent directory exists with proper permissions
    let directory = URL(fileURLWithPath: dbPath).deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700]
    )

    let connection: Connection
    do {
      connection = try Connection(dbPath)

      // Configure database with security and performance settings
      try connection.execute("PRAGMA journal_mode = WAL")
      try connection.execute("PRAGMA synchronous = NORMAL")
      try connection.execute("PRAGMA foreign_keys = ON")
    } catch {
      throw EventCLIError.unknown(
        "Failed to open database at \(dbPath): \(error.localizedDescription)")
    }

    // Set file permissions to 0600 (owner read/write only)
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: dbPath) {
      do {
        try fileManager.setAttributes(
          [.posixPermissions: 0o600],
          ofItemAtPath: dbPath
        )
      } catch {
        throw EventCLIError.unknown(
          "Failed to set database file permissions: \(error.localizedDescription)"
        )
      }
    }

    // Run migrations before wrapping in actor
    do {
      try runMigrations(on: connection)
    } catch {
      throw EventCLIError.unknown("Database migration failed: \(error.localizedDescription)")
    }

    return SQLiteDatabase(connection: connection)
  }

  /// Returns the underlying Connection for direct use by services.
  /// Connection is thread-safe (uses internal serial queue).
  public nonisolated var databaseConnection: Connection {
    connection
  }

  // MARK: - Migrations

  private static func runMigrations(on connection: Connection) throws {
    // Check current schema version
    let currentVersion =
      try connection.scalar(
        "PRAGMA user_version"
      ) as! Int64

    guard currentVersion < 1 else { return }

    // Migration v1: Create initial tables
    try connection.transaction {
      // Main data tables
      try connection.execute(
        """
          CREATE TABLE IF NOT EXISTS reminders (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            last_modified TEXT NOT NULL,
            deleted INTEGER DEFAULT 0,
            updated_at TEXT DEFAULT (datetime('now')),
            is_local_only INTEGER DEFAULT 0
          )
        """)

      try connection.execute(
        """
          CREATE TABLE IF NOT EXISTS calendar_events (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            last_modified TEXT NOT NULL,
            deleted INTEGER DEFAULT 0,
            updated_at TEXT DEFAULT (datetime('now')),
            is_local_only INTEGER DEFAULT 0
          )
        """)

      try connection.execute(
        """
          CREATE TABLE IF NOT EXISTS reminder_lists (
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            last_modified TEXT NOT NULL,
            deleted INTEGER DEFAULT 0,
            updated_at TEXT DEFAULT (datetime('now')),
            is_local_only INTEGER DEFAULT 0
          )
        """)

      // Sync metadata tables
      try connection.execute(
        """
          CREATE TABLE IF NOT EXISTS sync_cursors (
            entity_type TEXT PRIMARY KEY,
            cursor TEXT
          )
        """)

      try connection.execute(
        """
          CREATE TABLE IF NOT EXISTS sync_id_mappings (
            remote_id TEXT PRIMARY KEY,
            local_id TEXT NOT NULL,
            entity_type TEXT NOT NULL
          )
        """)

      try connection.execute(
        """
          CREATE TABLE IF NOT EXISTS sync_state (
            remote_id TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,
            last_modified TEXT NOT NULL,
            snapshot TEXT
          )
        """)

      // Create indexes on updated_at for performance
      try connection.execute(
        "CREATE INDEX IF NOT EXISTS idx_reminders_updated_at ON reminders(updated_at)")
      try connection.execute(
        "CREATE INDEX IF NOT EXISTS idx_calendar_events_updated_at ON calendar_events(updated_at)")
      try connection.execute(
        "CREATE INDEX IF NOT EXISTS idx_reminder_lists_updated_at ON reminder_lists(updated_at)")

      // Update schema version
      try connection.execute("PRAGMA user_version = 1")
    }
  }
}

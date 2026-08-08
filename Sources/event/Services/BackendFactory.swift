import EventModels
import EventSync
import Foundation

// MARK: - Backend Factory

/// Creates the appropriate backend services for the current platform.
/// On macOS, returns EventKit-backed services for local Apple data.
/// On Linux, returns SQLite-backed services for local storage with sync via D1.
enum BackendFactory {
  #if canImport(EventKit)
    static func makeRemindersBackend() async throws -> any RemindersBackend {
      return ReminderService()
    }

    static func makeCalendarBackend() async throws -> any CalendarBackend {
      return CalendarService()
    }

    static func makeListsBackend() async throws -> any ListsBackend {
      return ListService()
    }

    /// macOS-only: creates a SyncService for bidirectional push/pull. The body
    /// encryptor is built from `EVENT_ENCRYPTION_KEY`; when the key is absent the
    /// service still syncs lists but throws a helpful error on reminder/event sync.
    static func makeSyncService() async throws -> any SyncServiceProtocol {
      let config = try SyncConfigStore.load()
      let encryptor = try? EventEncryptor.fromEnvironment()
      return SyncService(config: config, encryptor: encryptor)
    }
  #else
    static func makeRemindersBackend() async throws -> any RemindersBackend {
      let db = try SQLiteDatabase.open()
      return SQLiteReminderService(connection: db.databaseConnection)
    }

    static func makeCalendarBackend() async throws -> any CalendarBackend {
      let db = try SQLiteDatabase.open()
      return SQLiteCalendarService(connection: db.databaseConnection)
    }

    static func makeListsBackend() async throws -> any ListsBackend {
      let db = try SQLiteDatabase.open()
      return SQLiteListService(connection: db.databaseConnection)
    }

    /// Linux: creates a LinuxSyncService for bidirectional push/pull between SQLite
    /// and D1. The body encryptor is built from `EVENT_ENCRYPTION_KEY`; without it,
    /// list sync works but reminder/event sync throws a helpful error.
    static func makeSyncService() async throws -> any SyncServiceProtocol {
      let config = try SyncConfigStore.load()
      let db = try SQLiteDatabase.open()
      let encryptor = try? EventEncryptor.fromEnvironment()
      return LinuxSyncService(config: config, database: db, encryptor: encryptor)
    }
  #endif
}

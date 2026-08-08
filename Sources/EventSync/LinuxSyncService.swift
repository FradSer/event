import AppleSyncKit
import EventModels
import Foundation
import SQLite

// MARK: - Linux Sync Service

/// Sync service for non-EventKit platforms (Linux, etc.) that uses SQLite as the
/// local store. Delegates the push/pull algorithm to the shared
/// `AppleSyncKit.SyncEngine` (local-only strategy), encrypting sensitive fields on
/// push and decrypting on pull so the local store always holds plaintext.
public actor LinuxSyncService: SyncServiceProtocol {
  private let connection: Connection
  private let syncClient: D1SyncClient
  private let encryptor: EventEncryptor?

  public init(config: SyncConfig, database: SQLiteDatabase, encryptor: EventEncryptor?) {
    self.connection = database.databaseConnection
    self.syncClient = D1SyncClient(config: config)
    self.encryptor = encryptor
  }

  public func shutdown() async throws {
    try await syncClient.shutdown()
  }

  private func requireEncryptor() throws -> EventEncryptor {
    guard let encryptor else {
      throw EncryptionError.keyNotConfigured("EVENT_ENCRYPTION_KEY")
    }
    return encryptor
  }

  private var dbStore: SQLiteSyncStore { SQLiteSyncStore(connection: connection) }

  // MARK: - Push

  public func pushReminders() async throws -> PushResult {
    let encryptor = try requireEncryptor()
    let dbStore = self.dbStore
    let allItems: [Reminder] = try dbStore.fetchNonDeleted(from: "reminders")
    let localOnly: [Reminder] = try dbStore.fetchLocalOnly(from: "reminders")
    let deletedRecords = try dbStore.fetchDeletedRecords(from: "reminders")

    return try await SyncEngine.pushLocalOnly(
      allItems: allItems, localOnlyItems: localOnly, deletedRecords: deletedRecords,
      getId: { $0.id }, store: SyncConfigStore.store,
      defaultState: SyncState(), stateKeyPath: \.reminders,
      defaultMapping: SyncIdMapping(), mappingKeyPath: \.reminders,
      volatileKeys: eventSnapshotVolatileKeys,
      deletionCandidates: { $0.deletionCandidates(currentRemoteIds: $1) },
      push: { items, overrides, lastModified in
        let encrypted = try await encryptor.encryptReminders(items)
        return try await self.syncClient.push(
          entity: "reminders", items: encrypted, id: { $0.id },
          idOverrides: overrides, lastModifiedByRemoteId: lastModified)
      },
      delete: { try await self.syncClient.delete(entity: "reminders", id: $0, lastModified: $1) },
      clearLocalOnly: { try dbStore.clearLocalOnly(table: "reminders", ids: $0) },
      removeRecord: { try dbStore.removeRecord(table: "reminders", id: $0) })
  }

  public func pushEvents() async throws -> PushResult {
    let encryptor = try requireEncryptor()
    let dbStore = self.dbStore
    let allItems: [CalendarEvent] = try dbStore.fetchNonDeleted(from: "calendar_events")
    let localOnly: [CalendarEvent] = try dbStore.fetchLocalOnly(from: "calendar_events")
    let deletedRecords = try dbStore.fetchDeletedRecords(from: "calendar_events")

    return try await SyncEngine.pushLocalOnly(
      allItems: allItems, localOnlyItems: localOnly, deletedRecords: deletedRecords,
      getId: { $0.id }, store: SyncConfigStore.store,
      defaultState: SyncState(), stateKeyPath: \.calendarEvents,
      defaultMapping: SyncIdMapping(), mappingKeyPath: \.calendarEvents,
      volatileKeys: calendarEventSnapshotVolatileKeys,
      deletionCandidates: { $0.deletionCandidates(currentRemoteIds: $1) },
      push: { items, overrides, lastModified in
        let encrypted = try await encryptor.encryptEvents(items)
        return try await self.syncClient.push(
          entity: "calendar_events", items: encrypted, id: { $0.id },
          idOverrides: overrides, lastModifiedByRemoteId: lastModified)
      },
      recordExtra: { entityState, event, remoteId in
        entityState.recordDateRange(
          event.syncDateRange(), for: remoteId)
      },
      delete: {
        try await self.syncClient.delete(entity: "calendar_events", id: $0, lastModified: $1)
      },
      clearLocalOnly: { try dbStore.clearLocalOnly(table: "calendar_events", ids: $0) },
      removeRecord: { try dbStore.removeRecord(table: "calendar_events", id: $0) })
  }

  public func pushLists() async throws -> PushResult {
    let dbStore = self.dbStore
    let allItems: [ReminderList] = try dbStore.fetchNonDeleted(from: "reminder_lists")
    let localOnly: [ReminderList] = try dbStore.fetchLocalOnly(from: "reminder_lists")
    let deletedRecords = try dbStore.fetchDeletedRecords(from: "reminder_lists")

    return try await SyncEngine.pushLocalOnly(
      allItems: allItems, localOnlyItems: localOnly, deletedRecords: deletedRecords,
      getId: { $0.id }, store: SyncConfigStore.store,
      defaultState: SyncState(), stateKeyPath: \.reminderLists,
      defaultMapping: SyncIdMapping(), mappingKeyPath: \.reminderLists,
      volatileKeys: eventSnapshotVolatileKeys,
      deletionCandidates: { $0.deletionCandidates(currentRemoteIds: $1) },
      push: { items, overrides, lastModified in
        try await self.syncClient.push(
          entity: "reminder_lists", items: items, id: { $0.id },
          idOverrides: overrides, lastModifiedByRemoteId: lastModified)
      },
      delete: {
        try await self.syncClient.delete(entity: "reminder_lists", id: $0, lastModified: $1)
      },
      clearLocalOnly: { try dbStore.clearLocalOnly(table: "reminder_lists", ids: $0) },
      removeRecord: { try dbStore.removeRecord(table: "reminder_lists", id: $0) })
  }

  // MARK: - Pull

  public func pullReminders() async throws -> PullSummary {
    let encryptor = try requireEncryptor()
    let dbStore = self.dbStore
    let local: [Reminder] = try dbStore.fetchNonDeleted(from: "reminders")
    let localLastModified = lastModifiedIndex(
      local.map { (id: $0.id, lastModified: $0.lastModifiedDate, creationDate: $0.creationDate) })
    let localIds = Set(local.map(\.id))

    return try await SyncEngine.pull(
      entityName: "reminders", store: SyncConfigStore.store,
      defaultState: SyncState(), stateKeyPath: \.reminders,
      defaultCursors: SyncCursors(), cursorKeyPath: \.reminders,
      defaultMapping: SyncIdMapping(), mappingKeyPath: \.reminders,
      volatileKeys: eventSnapshotVolatileKeys,
      localLastModifiedById: localLastModified,
      localIdsWithoutTimestamp: localIds.subtracting(Set(localLastModified.keys)),
      isNotFound: EventSyncRules.isNotFound,
      pull: { cursor in
        let response: PullResponse<Reminder> = try await self.syncClient.pull(
          entity: "reminders", cursor: cursor)
        return try await encryptor.decryptResponse(response)
      },
      applyDelete: { try dbStore.hardDeleteRecord(table: "reminders", id: $0) },
      applyUpsert: { localId, item in
        try dbStore.upsertRecord(
          table: "reminders", id: localId, data: item.data, lastModified: item.lastModified)
        return nil
      })
  }

  public func pullEvents() async throws -> PullSummary {
    let encryptor = try requireEncryptor()
    let dbStore = self.dbStore
    let local: [CalendarEvent] = try dbStore.fetchNonDeleted(from: "calendar_events")
    let localLastModified = lastModifiedIndex(
      local.map { (id: $0.id, lastModified: $0.lastModifiedDate, creationDate: $0.creationDate) })
    let localIds = Set(local.map(\.id))

    return try await SyncEngine.pull(
      entityName: "calendar events", store: SyncConfigStore.store,
      defaultState: SyncState(), stateKeyPath: \.calendarEvents,
      defaultCursors: SyncCursors(), cursorKeyPath: \.calendarEvents,
      defaultMapping: SyncIdMapping(), mappingKeyPath: \.calendarEvents,
      volatileKeys: calendarEventSnapshotVolatileKeys,
      localLastModifiedById: localLastModified,
      localIdsWithoutTimestamp: localIds.subtracting(Set(localLastModified.keys)),
      isNotFound: EventSyncRules.isNotFound,
      pull: { cursor in
        let response: PullResponse<CalendarEvent> = try await self.syncClient.pull(
          entity: "calendar_events", cursor: cursor)
        return try await encryptor.decryptResponse(response)
      },
      applyDelete: { try dbStore.hardDeleteRecord(table: "calendar_events", id: $0) },
      applyUpsert: { localId, item in
        try dbStore.upsertRecord(
          table: "calendar_events", id: localId, data: item.data, lastModified: item.lastModified)
        return nil
      },
      recordExtra: { entityState, item in
        entityState.recordDateRange(
          item.data.syncDateRange(), for: item.id)
      })
  }

  public func pullLists() async throws -> PullSummary {
    let dbStore = self.dbStore
    return try await SyncEngine.pull(
      entityName: "reminder lists", store: SyncConfigStore.store,
      defaultState: SyncState(), stateKeyPath: \.reminderLists,
      defaultCursors: SyncCursors(), cursorKeyPath: \.reminderLists,
      defaultMapping: SyncIdMapping(), mappingKeyPath: \.reminderLists,
      volatileKeys: eventSnapshotVolatileKeys,
      localLastModifiedById: [:],
      localIdsWithoutTimestamp: [],
      isNotFound: EventSyncRules.isNotFound,
      pull: { cursor in
        try await self.syncClient.pull(entity: "reminder_lists", cursor: cursor)
          as PullResponse<ReminderList>
      },
      applyDelete: { try dbStore.hardDeleteRecord(table: "reminder_lists", id: $0) },
      applyUpsert: { localId, item in
        try dbStore.upsertRecord(
          table: "reminder_lists", id: localId, data: item.data, lastModified: item.lastModified)
        return nil
      })
  }

  // MARK: - Helpers

  private nonisolated func lastModifiedIndex(
    _ pairs: [(id: String, lastModified: String?, creationDate: String?)]
  ) -> [String: String] {
    var index: [String: String] = [:]
    for pair in pairs {
      if let lastModified = pair.lastModified {
        index[pair.id] = lastModified
      } else if let creationDate = pair.creationDate {
        index[pair.id] = creationDate
      }
    }
    return index
  }
}

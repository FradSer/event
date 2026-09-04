import AppleSyncKit
import EventModels
import Foundation
import SQLite

public actor LinuxSyncService: SyncServiceProtocol {
  private let coordinator: SyncCoordinator
  private let database: SQLiteDatabase
  private let encryptor: EventEncryptor?

  public init(config: SyncConfig, database: SQLiteDatabase, encryptor: EventEncryptor?) {
    self.coordinator = SyncCoordinator(config: config, store: SyncConfigStore.store)
    self.database = database
    self.encryptor = encryptor
  }

  public func shutdown() async throws {}

  public func pushReminders() async throws -> PushResult {
    try await coordinator.push(source: reminderSource())
  }

  public func pushEvents() async throws -> PushResult {
    try await coordinator.push(source: eventSource())
  }

  public func pushLists() async throws -> PushResult {
    try await coordinator.push(source: listSource())
  }

  public func pullReminders() async throws -> PullSummary {
    try await coordinator.pull(source: reminderSource())
  }

  public func pullEvents() async throws -> PullSummary {
    try await coordinator.pull(source: eventSource())
  }

  public func pullLists() async throws -> PullSummary {
    try await coordinator.pull(source: listSource())
  }

  public func push(entities: [SyncEntity]) async throws -> [String: PushResult] {
    try await coordinator.withLock { session in
      try await push(entities: entities, session: session)
    }
  }

  public func pull(entities: [SyncEntity]) async throws -> [String: PullSummary] {
    try await coordinator.withLock { session in
      try await pull(entities: entities, session: session)
    }
  }

  public func fullSync(entities: [SyncEntity]) async throws -> FullSyncResult {
    try await coordinator.withLock { session in
      let pull = try await pull(entities: entities, session: session)
      let push = try await push(entities: entities, session: session)
      return FullSyncResult(pull: pull, push: push)
    }
  }

  private func push(
    entities: [SyncEntity], session: LockedSyncSession
  ) async throws -> [String: PushResult] {
    var output = [String: PushResult]()
    for entity in SyncEntity.pushOrder
    where entities.contains(entity) {
      switch entity {
      case .reminderLists:
        output["reminderLists"] = try await session.push(source: listSource())
      case .reminders:
        output["reminders"] = try await session.push(source: reminderSource())
      case .calendarEvents:
        output["calendarEvents"] = try await session.push(source: eventSource())
      }
    }
    return output
  }

  private func pull(
    entities: [SyncEntity], session: LockedSyncSession
  ) async throws -> [String: PullSummary] {
    var output = [String: PullSummary]()
    for entity in SyncEntity.pullOrder
    where entities.contains(entity) {
      switch entity {
      case .reminderLists:
        output["reminderLists"] = try await session.pull(source: listSource())
      case .reminders:
        output["reminders"] = try await session.pull(source: reminderSource())
      case .calendarEvents:
        output["calendarEvents"] = try await session.pull(source: eventSource())
      }
    }
    return output
  }

  private func reminderSource() throws -> LinuxReminderSyncSource {
    guard let encryptor else {
      throw EncryptionError.keyNotConfigured("EVENT_ENCRYPTION_KEY")
    }
    return LinuxReminderSyncSource(store: syncStore, encryptor: encryptor)
  }

  private func eventSource() throws -> LinuxEventSyncSource {
    guard let encryptor else {
      throw EncryptionError.keyNotConfigured("EVENT_ENCRYPTION_KEY")
    }
    return LinuxEventSyncSource(store: syncStore, encryptor: encryptor)
  }

  private func listSource() -> LinuxListSyncSource {
    LinuxListSyncSource(store: syncStore)
  }

  private var syncStore: SQLiteSyncStore {
    SQLiteSyncStore(connection: database.databaseConnection)
  }
}

private struct LinuxListSyncSource: LocalSyncSource {
  private let base: FlaggedSyncSource<ReminderList>

  init(store: SQLiteSyncStore) {
    self.base = FlaggedSyncSource(
      entityName: "reminder_lists", table: "reminder_lists", store: store,
      getId: { $0.id })
  }

  var entityName: String { base.entityName }
  func getLocalId(_ record: ReminderList) -> String { base.getLocalId(record) }
  func localRecordState(for localId: String) async throws -> LocalRecordState { .acceptRemote }
  func changes(context: SyncAdapterContext) async throws -> LocalSyncChanges<ReminderList> {
    try await base.changes(context: context)
  }
  func acknowledgePushed(localIds: [String]) async throws {
    try await base.acknowledgePushed(localIds: localIds)
  }
  func finalizeDeleted(localId: String) async throws {
    try await base.finalizeDeleted(localId: localId)
  }
  func applyRemoteUpsert(
    _ record: ReminderList, localId: String, remoteId: String, lastModified: String
  ) async throws -> String? {
    try await base.applyRemoteUpsert(
      record, localId: localId, remoteId: remoteId, lastModified: lastModified)
  }
  func applyRemoteDelete(localId: String) async throws {
    try await base.applyRemoteDelete(localId: localId)
  }
}

private struct LinuxReminderSyncSource: LocalSyncSource {
  private let base: FlaggedSyncSource<Reminder>
  private let encryptor: EventEncryptor

  init(store: SQLiteSyncStore, encryptor: EventEncryptor) {
    self.base = FlaggedSyncSource(
      entityName: "reminders", table: "reminders", store: store, getId: { $0.id })
    self.encryptor = encryptor
  }

  var entityName: String { base.entityName }
  func getLocalId(_ record: Reminder) -> String { base.getLocalId(record) }
  func localRecordState(for localId: String) async throws -> LocalRecordState {
    try await base.localRecordState(for: localId)
  }
  func changes(context: SyncAdapterContext) async throws -> LocalSyncChanges<Reminder> {
    try await base.changes(context: context)
  }
  func transformForPush(_ record: Reminder) async throws -> Reminder {
    try await encryptor.encryptReminders([record])[0]
  }
  func transformForPull(_ record: Reminder) async throws -> Reminder {
    try await encryptor.decryptReminders([record])[0]
  }
  func acknowledgePushed(localIds: [String]) async throws {
    try await base.acknowledgePushed(localIds: localIds)
  }
  func finalizeDeleted(localId: String) async throws {
    try await base.finalizeDeleted(localId: localId)
  }
  func applyRemoteUpsert(
    _ record: Reminder, localId: String, remoteId: String, lastModified: String
  ) async throws -> String? {
    try await base.applyRemoteUpsert(
      record, localId: localId, remoteId: remoteId, lastModified: lastModified)
  }
  func applyRemoteDelete(localId: String) async throws {
    try await base.applyRemoteDelete(localId: localId)
  }
}

struct LinuxEventSyncSource: LocalSyncSource {
  private let base: FlaggedSyncSource<CalendarEvent>
  private let encryptor: EventEncryptor

  init(store: SQLiteSyncStore, encryptor: EventEncryptor) {
    self.base = FlaggedSyncSource(
      entityName: "calendar_events", table: "calendar_events", store: store, getId: { $0.id })
    self.encryptor = encryptor
  }

  var entityName: String { base.entityName }
  func getLocalId(_ record: CalendarEvent) -> String { base.getLocalId(record) }
  func localRecordState(for localId: String) async throws -> LocalRecordState {
    try await base.localRecordState(for: localId)
  }
  func changes(context: SyncAdapterContext) async throws -> LocalSyncChanges<CalendarEvent> {
    try await base.changes(context: context)
  }
  func transformForPush(_ record: CalendarEvent) async throws -> CalendarEvent {
    try await encryptor.encryptEvents([record])[0]
  }
  func transformForPull(_ record: CalendarEvent) async throws -> CalendarEvent {
    try await encryptor.decryptEvents([record])[0]
  }
  func recordPushMetadata(
    _ record: CalendarEvent, remoteId: String, state: inout SyncEntityState
  ) throws {
    Self.recordDateRange(record, remoteId: remoteId, state: &state)
  }
  func recordPullMetadata(
    _ record: CalendarEvent, remoteId: String, state: inout SyncEntityState
  ) throws {
    Self.recordDateRange(record, remoteId: remoteId, state: &state)
  }

  static func recordDateRange(
    _ record: CalendarEvent, remoteId: String, state: inout SyncEntityState
  ) {
    state.recordDateRange(record.syncDateRange(), for: remoteId)
  }
  func acknowledgePushed(localIds: [String]) async throws {
    try await base.acknowledgePushed(localIds: localIds)
  }
  func finalizeDeleted(localId: String) async throws {
    try await base.finalizeDeleted(localId: localId)
  }
  func applyRemoteUpsert(
    _ record: CalendarEvent, localId: String, remoteId: String, lastModified: String
  ) async throws -> String? {
    try await base.applyRemoteUpsert(
      record, localId: localId, remoteId: remoteId, lastModified: lastModified)
  }
  func applyRemoteDelete(localId: String) async throws {
    try await base.applyRemoteDelete(localId: localId)
  }
}

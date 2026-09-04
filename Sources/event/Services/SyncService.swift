#if canImport(EventKit)

  import AppleSyncKit
  import EventCommands
  import EventKit
  import EventModels
  import EventSync
  import Foundation

  actor SyncService: SyncServiceProtocol {
    private let reminderService = ReminderService()
    private let calendarService = CalendarService()
    private let listService = ListService()
    private let coordinator: SyncCoordinator
    private let encryptor: EventEncryptor?

    init(config: SyncConfig, encryptor: EventEncryptor?) {
      self.coordinator = SyncCoordinator(config: config, store: SyncConfigStore.store)
      self.encryptor = encryptor
    }

    func shutdown() async throws {}

    func pushReminders() async throws -> PushResult {
      try await coordinator.push(source: reminderSource())
    }

    func pushEvents() async throws -> PushResult {
      try await coordinator.push(source: eventSource())
    }

    func pushLists() async throws -> PushResult {
      try await coordinator.push(source: listSource())
    }

    func pullReminders() async throws -> PullSummary {
      try await coordinator.pull(source: reminderSource())
    }

    func pullEvents() async throws -> PullSummary {
      try await coordinator.pull(source: eventSource())
    }

    func pullLists() async throws -> PullSummary {
      try await coordinator.pull(source: listSource())
    }

    func push(entities: [SyncEntity]) async throws -> [String: PushResult] {
      try await coordinator.withLock { session in
        try await push(entities: entities, session: session)
      }
    }

    func pull(entities: [SyncEntity]) async throws -> [String: PullSummary] {
      try await coordinator.withLock { session in
        try await pull(entities: entities, session: session)
      }
    }

    func fullSync(entities: [SyncEntity]) async throws -> FullSyncResult {
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

    private func reminderSource() throws -> EventKitReminderSyncSource {
      guard let encryptor else {
        throw EncryptionError.keyNotConfigured("EVENT_ENCRYPTION_KEY")
      }
      return EventKitReminderSyncSource(
        service: reminderService, listService: listService, encryptor: encryptor)
    }

    private func eventSource() throws -> EventKitCalendarSyncSource {
      guard let encryptor else {
        throw EncryptionError.keyNotConfigured("EVENT_ENCRYPTION_KEY")
      }
      return EventKitCalendarSyncSource(service: calendarService, encryptor: encryptor)
    }

    private func listSource() -> EventKitListSyncSource {
      EventKitListSyncSource(service: listService)
    }
  }

  private struct EventKitReminderSyncSource: LocalSyncSource {
    let service: ReminderService
    let listService: ListService
    let encryptor: EventEncryptor

    var entityName: String { "reminders" }
    var volatileKeys: Set<String> { eventSnapshotVolatileKeys }
    func getLocalId(_ record: Reminder) -> String { record.id }

    func localRecordState(for localId: String) async throws -> LocalRecordState {
      let records = try await service.fetchReminders(showCompleted: true)
      guard let record = records.first(where: { $0.id == localId }) else { return .absent }
      guard let timestamp = record.lastModifiedDate ?? record.creationDate else { return .unknown }
      return .timestamp(timestamp)
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

    func acknowledgePushed(localIds: [String]) async throws {}
    func finalizeDeleted(localId: String) async throws {}

    func applyRemoteUpsert(
      _ item: Reminder, localId: String, remoteId: String, lastModified: String
    ) async throws -> String? {
      do {
        _ = try await service.updateReminder(
          id: localId, title: item.title, completed: item.isCompleted, notes: item.notes,
          dueDate: item.dueDate, clearDue: item.dueDate == nil, startDate: item.startDate,
          clearStart: item.startDate == nil, priority: item.priority, url: item.url,
          useShortcuts: false)
        return nil
      } catch let error as EventCLIError where error.isNotFound {
        try await ensureListExists(named: item.list)
        let created = try await service.createReminder(
          title: item.title, listName: item.list, notes: item.notes, url: item.url,
          dueDate: item.dueDate, priority: item.priority, useShortcuts: false)
        if item.isCompleted || item.startDate != nil {
          _ = try await service.updateReminder(
            id: created.id, completed: item.isCompleted, startDate: item.startDate,
            useShortcuts: false)
        }
        return created.id
      }
    }

    func applyRemoteDelete(localId: String) async throws {
      try await service.deleteReminder(id: localId)
    }

    private var base: SnapshotSyncSource<Reminder> {
      SnapshotSyncSource(
        entityName: entityName,
        fetchRecords: { try await service.fetchReminders(showCompleted: true) },
        getId: { $0.id }, volatileKeys: volatileKeys,
        localLastModified: { localId in
          let records = try await service.fetchReminders(showCompleted: true)
          guard let record = records.first(where: { $0.id == localId }) else { return nil }
          return record.lastModifiedDate ?? record.creationDate
        },
        applyUpsert: { _, _, _, _ in nil },
        applyDelete: { _ in })
    }

    private func ensureListExists(named name: String) async throws {
      let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !normalized.isEmpty else { return }
      let lists = try await listService.fetchLists()
      guard !lists.contains(where: { $0.title == normalized }) else { return }
      _ = try await listService.createList(name: normalized)
    }
  }

  struct EventKitCalendarSyncSource: LocalSyncSource {
    let service: CalendarService
    let encryptor: EventEncryptor
    let window: (start: String, end: String)

    init(service: CalendarService, encryptor: EventEncryptor) {
      self.service = service
      self.encryptor = encryptor
      self.window = Self.makeWindow()
    }

    var entityName: String { "calendar_events" }
    var volatileKeys: Set<String> { calendarEventSnapshotVolatileKeys }
    func getLocalId(_ record: CalendarEvent) -> String { record.id }

    func localRecordState(for localId: String) async throws -> LocalRecordState {
      let records = try await fetchRecords()
      guard let record = records.first(where: { $0.id == localId }) else { return .absent }
      guard let timestamp = record.lastModifiedDate ?? record.creationDate else { return .unknown }
      return .timestamp(timestamp)
    }

    func changes(context: SyncAdapterContext) async throws -> LocalSyncChanges<CalendarEvent> {
      let discovered = try await base.changes(context: context)
      let records = try await fetchRecords()
      let currentRemoteIds = Set(records.map { context.localToRemoteId[$0.id] ?? $0.id })
      let range = CalendarEvent.syncDateRange(start: window.start, end: window.end)
      let deletionCandidates = context.entityState.deletionCandidates(
        currentRemoteIds: currentRemoteIds, withinRange: range)
      let deletionTimestamps = Self.deletionTimestamps(
        discovered.deletionLastModifiedByRemoteId, for: deletionCandidates)
      return LocalSyncChanges(
        records: discovered.records,
        lastModifiedByRemoteId: discovered.lastModifiedByRemoteId,
        deletionCandidates: deletionCandidates,
        deletionLastModifiedByRemoteId: deletionTimestamps)
    }

    static func deletionTimestamps(
      _ timestamps: [String: String], for candidates: [String]
    ) -> [String: String] {
      timestamps.filter { candidates.contains($0.key) }
    }

    func transformForPush(_ record: CalendarEvent) async throws -> CalendarEvent {
      try await encryptor.encryptEvents([record])[0]
    }

    func transformForPull(_ record: CalendarEvent) async throws -> CalendarEvent {
      try await encryptor.decryptEvents([record])[0]
    }

    func shouldApplyPulledItem(_ item: PullItem<CalendarEvent>) async throws -> Bool {
      item.data.syncDateRange().overlaps(
        CalendarEvent.syncDateRange(start: window.start, end: window.end))
    }

    func filterDeletionCandidates(
      _ candidates: [String], context: SyncAdapterContext
    ) async throws -> [String] {
      var confirmed = [String]()
      for remoteId in candidates {
        let localId =
          context.localToRemoteId.first(where: { $0.value == remoteId })?.key ?? remoteId
        if await service.eventExists(id: localId) { continue }
        confirmed.append(remoteId)
      }
      return confirmed
    }

    func recordPushMetadata(
      _ record: CalendarEvent, remoteId: String, state: inout SyncEntityState
    ) throws {
      state.recordDateRange(record.syncDateRange(), for: remoteId)
    }

    func recordPullMetadata(
      _ record: CalendarEvent, remoteId: String, state: inout SyncEntityState
    ) throws {
      state.recordDateRange(record.syncDateRange(), for: remoteId)
    }

    func acknowledgePushed(localIds: [String]) async throws {}
    func finalizeDeleted(localId: String) async throws {}

    func applyRemoteUpsert(
      _ item: CalendarEvent, localId: String, remoteId: String, lastModified: String
    ) async throws -> String? {
      do {
        _ = try await service.updateEvent(
          id: localId, title: item.title, startDate: item.startDate, endDate: item.endDate,
          location: item.location, notes: item.notes, url: item.url,
          timeZoneIdentifier: item.syncTimeZoneIdentifier,
          clearTimeZone: item.shouldClearTimeZoneOnSync,
          dateFormatVersion: item.dateFormatVersion)
        return nil
      } catch let error as EventCLIError where error.isNotFound {
        let created = try await service.createEvent(
          title: item.title, startDate: item.startDate, endDate: item.endDate,
          calendarName: item.calendar, location: item.location, notes: item.notes, url: item.url,
          timeZoneIdentifier: item.syncTimeZoneIdentifier,
          dateFormatVersion: item.dateFormatVersion)
        return created.id
      }
    }

    func applyRemoteDelete(localId: String) async throws {
      try await service.deleteEvent(id: localId)
    }

    private func fetchRecords() async throws -> [CalendarEvent] {
      try await service.fetchEvents(startDate: window.start, endDate: window.end)
    }

    private var base: SnapshotSyncSource<CalendarEvent> {
      SnapshotSyncSource(
        entityName: entityName, fetchRecords: { try await fetchRecords() }, getId: { $0.id },
        volatileKeys: volatileKeys,
        localLastModified: { localId in
          let records = try await fetchRecords()
          guard let record = records.first(where: { $0.id == localId }) else { return nil }
          return record.lastModifiedDate ?? record.creationDate
        }, applyUpsert: { _, _, _, _ in nil }, applyDelete: { _ in })
    }

    private static func makeWindow() -> (start: String, end: String) {
      let calendar = Calendar.current
      let today = calendar.startOfDay(for: Date())
      let start = calendar.date(byAdding: .year, value: -1, to: today) ?? today
      let end = calendar.date(byAdding: .year, value: 2, to: today) ?? today
      return (
        DateFormatter.eventDate.string(from: start), DateFormatter.eventDate.string(from: end)
      )
    }
  }

  private struct EventKitListSyncSource: LocalSyncSource {
    let service: ListService

    var entityName: String { "reminder_lists" }
    var volatileKeys: Set<String> { eventSnapshotVolatileKeys }
    func getLocalId(_ record: ReminderList) -> String { record.id }
    func localRecordState(for localId: String) async throws -> LocalRecordState { .acceptRemote }
    func changes(context: SyncAdapterContext) async throws -> LocalSyncChanges<ReminderList> {
      try await base.changes(context: context)
    }
    func acknowledgePushed(localIds: [String]) async throws {}
    func finalizeDeleted(localId: String) async throws {}

    func applyRemoteUpsert(
      _ item: ReminderList, localId: String, remoteId: String, lastModified: String
    ) async throws -> String? {
      do {
        _ = try await service.updateList(id: localId, name: item.title)
        return nil
      } catch let error as EventCLIError where error.isNotFound {
        return try await service.createList(name: item.title).id
      }
    }

    func applyRemoteDelete(localId: String) async throws {
      try await service.deleteList(id: localId)
    }

    private var base: SnapshotSyncSource<ReminderList> {
      SnapshotSyncSource(
        entityName: entityName, fetchRecords: { try await service.fetchLists() },
        getId: { $0.id }, volatileKeys: volatileKeys,
        applyUpsert: { _, _, _, _ in nil }, applyDelete: { _ in })
    }
  }

#endif

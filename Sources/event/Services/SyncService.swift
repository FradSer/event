#if canImport(EventKit)

  import AppleSyncKit
  import EventCommands
  import EventKit
  import EventModels
  import EventSync
  import Foundation

  // MARK: - Sync Service (macOS)

  /// Bidirectional sync between local EventKit data and Cloudflare D1, delegating
  /// the algorithm to the shared `AppleSyncKit.SyncEngine` (snapshot strategy).
  /// Sensitive fields are end-to-end encrypted on push and decrypted on pull, so
  /// the Worker only ever stores ciphertext.
  actor SyncService: SyncServiceProtocol {
    private let reminderService = ReminderService()
    private let calendarService = CalendarService()
    private let listService = ListService()
    private let syncClient: D1SyncClient
    private let encryptor: EventEncryptor?

    init(config: SyncConfig, encryptor: EventEncryptor?) {
      self.syncClient = D1SyncClient(config: config)
      self.encryptor = encryptor
    }

    func shutdown() async throws {
      try await syncClient.shutdown()
    }

    private func requireEncryptor() throws -> EventEncryptor {
      guard let encryptor else {
        throw EncryptionError.keyNotConfigured("EVENT_ENCRYPTION_KEY")
      }
      return encryptor
    }

    // MARK: - Push

    func pushReminders() async throws -> PushResult {
      let encryptor = try requireEncryptor()
      let reminders = try await reminderService.fetchReminders(showCompleted: true)
      return try await SyncEngine.pushSnapshot(
        items: reminders, getId: { $0.id }, store: SyncConfigStore.store,
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
        delete: { try await self.syncClient.delete(entity: "reminders", id: $0, lastModified: $1) })
    }

    func pushEvents() async throws -> PushResult {
      let encryptor = try requireEncryptor()
      // Syncs events within `eventSyncWindow()`. Events outside this window are excluded.
      let window = eventSyncWindow()
      let events = try await calendarService.fetchEvents(
        startDate: window.start, endDate: window.end)
      let fetchWindow = SyncDateRange(start: window.start, end: window.end)
      return try await SyncEngine.pushSnapshot(
        items: events, getId: { $0.id }, store: SyncConfigStore.store,
        defaultState: SyncState(), stateKeyPath: \.calendarEvents,
        defaultMapping: SyncIdMapping(), mappingKeyPath: \.calendarEvents,
        volatileKeys: eventSnapshotVolatileKeys,
        deletionCandidates: { entityState, currentRemoteIds in
          entityState.deletionCandidates(
            currentRemoteIds: currentRemoteIds, withinRange: fetchWindow)
        },
        push: { items, overrides, lastModified in
          let encrypted = try await encryptor.encryptEvents(items)
          return try await self.syncClient.push(
            entity: "calendar_events", items: encrypted, id: { $0.id },
            idOverrides: overrides, lastModifiedByRemoteId: lastModified)
        },
        recordExtra: { entityState, event, remoteId in
          entityState.recordDateRange(
            SyncDateRange(start: event.startDate, end: event.endDate), for: remoteId)
        },
        filterDeletionCandidates: { candidates, idMapping in
          var confirmed: [String] = []
          for remoteId in candidates {
            let localId = idMapping.calendarEvents[remoteId] ?? remoteId
            if await self.calendarService.eventExists(id: localId) { continue }
            confirmed.append(remoteId)
          }
          return confirmed
        },
        delete: {
          try await self.syncClient.delete(entity: "calendar_events", id: $0, lastModified: $1)
        })
    }

    func pushLists() async throws -> PushResult {
      let lists = try await listService.fetchLists()
      return try await SyncEngine.pushSnapshot(
        items: lists, getId: { $0.id }, store: SyncConfigStore.store,
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
        })
    }

    // MARK: - Pull

    func pullReminders() async throws -> PullSummary {
      let encryptor = try requireEncryptor()
      let localReminders = try await reminderService.fetchReminders(showCompleted: true)
      let localLastModified = lastModifiedIndex(
        localReminders.map {
          (id: $0.id, lastModified: $0.lastModifiedDate, creationDate: $0.creationDate)
        })
      let localIds = Set(localReminders.map(\.id))

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
        applyDelete: { try await self.reminderService.deleteReminder(id: $0) },
        applyUpsert: { localId, item in
          do {
            _ = try await self.reminderService.updateReminder(
              id: localId,
              title: item.data.title,
              completed: item.data.isCompleted,
              notes: item.data.notes,
              dueDate: item.data.dueDate,
              clearDue: item.data.dueDate == nil,
              startDate: item.data.startDate,
              clearStart: item.data.startDate == nil,
              priority: item.data.priority,
              url: item.data.url,
              useShortcuts: false
            )
            return nil
          } catch let error as EventCLIError where error.isNotFound {
            try await self.ensureReminderListExists(named: item.data.list)
            let created = try await self.reminderService.createReminder(
              title: item.data.title,
              listName: item.data.list,
              notes: item.data.notes,
              url: item.data.url,
              dueDate: item.data.dueDate,
              priority: item.data.priority,
              useShortcuts: false
            )
            if item.data.isCompleted || item.data.startDate != nil {
              _ = try await self.reminderService.updateReminder(
                id: created.id,
                completed: item.data.isCompleted,
                startDate: item.data.startDate,
                useShortcuts: false
              )
            }
            return created.id
          }
        })
    }

    func pullEvents() async throws -> PullSummary {
      let encryptor = try requireEncryptor()
      let window = eventSyncWindow()
      let localEvents = try await calendarService.fetchEvents(
        startDate: window.start, endDate: window.end)
      let localLastModified = lastModifiedIndex(
        localEvents.map {
          (id: $0.id, lastModified: $0.lastModifiedDate, creationDate: $0.creationDate)
        })
      let localIds = Set(localEvents.map(\.id))

      return try await SyncEngine.pull(
        entityName: "calendar events", store: SyncConfigStore.store,
        defaultState: SyncState(), stateKeyPath: \.calendarEvents,
        defaultCursors: SyncCursors(), cursorKeyPath: \.calendarEvents,
        defaultMapping: SyncIdMapping(), mappingKeyPath: \.calendarEvents,
        volatileKeys: eventSnapshotVolatileKeys,
        localLastModifiedById: localLastModified,
        localIdsWithoutTimestamp: localIds.subtracting(Set(localLastModified.keys)),
        isNotFound: EventSyncRules.isNotFound,
        pull: { cursor in
          let response: PullResponse<CalendarEvent> = try await self.syncClient.pull(
            entity: "calendar_events", cursor: cursor)
          return try await encryptor.decryptResponse(response)
        },
        applyDelete: { try await self.calendarService.deleteEvent(id: $0) },
        applyUpsert: { localId, item in
          do {
            _ = try await self.calendarService.updateEvent(
              id: localId,
              title: item.data.title,
              startDate: item.data.startDate,
              endDate: item.data.endDate,
              location: item.data.location,
              notes: item.data.notes,
              url: item.data.url
            )
            return nil
          } catch let error as EventCLIError where error.isNotFound {
            let created = try await self.calendarService.createEvent(
              title: item.data.title,
              startDate: item.data.startDate,
              endDate: item.data.endDate,
              calendarName: item.data.calendar,
              location: item.data.location,
              notes: item.data.notes,
              url: item.data.url
            )
            return created.id
          }
        },
        recordExtra: { entityState, item in
          entityState.recordDateRange(
            SyncDateRange(start: item.data.startDate, end: item.data.endDate), for: item.id)
        })
    }

    func pullLists() async throws -> PullSummary {
      // Reminder lists carry no modification timestamp, so the pull always
      // applies the server value (an empty conflict index disables the guard).
      try await SyncEngine.pull(
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
        applyDelete: { try await self.listService.deleteList(id: $0) },
        applyUpsert: { localId, item in
          do {
            _ = try await self.listService.updateList(id: localId, name: item.data.title)
            return nil
          } catch let error as EventCLIError where error.isNotFound {
            let created = try await self.listService.createList(name: item.data.title)
            return created.id
          }
        })
    }

    // MARK: - Helpers

    /// The calendar window synced by push and pull: one year back to two years ahead.
    private nonisolated func eventSyncWindow() -> (start: String, end: String) {
      let start = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
      let end = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
      return (
        DateFormatter.eventDate.string(from: start), DateFormatter.eventDate.string(from: end)
      )
    }

    /// Builds a `localId -> lastModified` index, preferring modification time and
    /// falling back to creation time when EventKit omits last-modified metadata.
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

    private func ensureReminderListExists(named listName: String) async throws {
      let normalizedName = listName.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !normalizedName.isEmpty else { return }
      let existingLists = try await listService.fetchLists()
      guard existingLists.contains(where: { $0.title == normalizedName }) == false else { return }
      _ = try await listService.createList(name: normalizedName)
    }
  }

#endif

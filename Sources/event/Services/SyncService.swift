import EventCommands
import EventKit
import EventModels
import EventSync
import Foundation

// MARK: - Sync Service

actor SyncService {
  private let reminderService = ReminderService()
  private let calendarService = CalendarService()
  private let listService = ListService()
  private let syncClient: D1SyncClient

  init(config: SyncConfig) {
    self.syncClient = D1SyncClient(config: config)
  }

  func shutdown() async throws {
    try await syncClient.shutdown()
  }

  // MARK: - Push

  func pushReminders() async throws -> PushResult {
    let reminders = try await reminderService.fetchReminders(showCompleted: true)
    var idMapping = SyncConfigStore.loadIdMapping()
    var state = SyncConfigStore.loadState()
    let localToRemote = invertMapping(idMapping.reminders)
    let currentRemoteIds = Set(reminders.map { localToRemote[$0.id] ?? $0.id })
    let deletedRemoteIds = state.reminders.deletionCandidates(currentRemoteIds: currentRemoteIds)
    let fallbackLastModified = DateFormatter.eventISO8601.string(from: Date())
    let lastModifiedByRemoteId = try Dictionary(
      uniqueKeysWithValues: reminders.map { reminder in
        let remoteId = localToRemote[reminder.id] ?? reminder.id
        return (
          remoteId,
          try state.reminders.lastModified(
            for: reminder,
            remoteId: remoteId,
            fallback: fallbackLastModified
          )
        )
      }
    )

    let result = try await syncClient.pushReminders(
      reminders,
      idOverrides: localToRemote,
      lastModifiedByRemoteId: lastModifiedByRemoteId
    )

    for remoteId in deletedRemoteIds {
      try await syncClient.deleteReminder(
        id: remoteId, lastModified: state.reminders.lastModifiedByRemoteId[remoteId])
      idMapping.reminders.removeValue(forKey: remoteId)
      state.reminders.removeRemoteId(remoteId)
    }

    for reminder in reminders {
      let remoteId = localToRemote[reminder.id] ?? reminder.id
      if let lastModified = lastModifiedByRemoteId[remoteId] {
        try state.reminders.recordSyncedValue(
          reminder,
          remoteId: remoteId,
          lastModified: lastModified
        )
      }
    }

    try SyncConfigStore.saveIdMapping(idMapping)
    try SyncConfigStore.saveState(state)
    return result
  }

  func pushEvents() async throws -> PushResult {
    // Syncs events within `eventSyncWindow()`. Events outside this window are excluded.
    let window = eventSyncWindow()
    let events = try await calendarService.fetchEvents(
      startDate: window.start,
      endDate: window.end
    )
    var idMapping = SyncConfigStore.loadIdMapping()
    var state = SyncConfigStore.loadState()
    let localToRemote = invertMapping(idMapping.calendarEvents)
    let currentRemoteIds = Set(events.map { localToRemote[$0.id] ?? $0.id })
    let fetchWindow = SyncDateRange(start: window.start, end: window.end)
    let deletedRemoteIds = state.calendarEvents.deletionCandidates(
      currentRemoteIds: currentRemoteIds,
      withinRange: fetchWindow
    )
    let fallbackLastModified = DateFormatter.eventISO8601.string(from: Date())
    let lastModifiedByRemoteId = try Dictionary(
      uniqueKeysWithValues: events.map { event in
        let remoteId = localToRemote[event.id] ?? event.id
        return (
          remoteId,
          try state.calendarEvents.lastModified(
            for: event,
            remoteId: remoteId,
            fallback: fallbackLastModified
          )
        )
      }
    )

    let result = try await syncClient.pushEvents(
      events,
      idOverrides: localToRemote,
      lastModifiedByRemoteId: lastModifiedByRemoteId
    )

    for remoteId in deletedRemoteIds {
      try await syncClient.deleteEvent(
        id: remoteId, lastModified: state.calendarEvents.lastModifiedByRemoteId[remoteId])
      idMapping.calendarEvents.removeValue(forKey: remoteId)
      state.calendarEvents.removeRemoteId(remoteId)
    }

    for event in events {
      let remoteId = localToRemote[event.id] ?? event.id
      if let lastModified = lastModifiedByRemoteId[remoteId] {
        try state.calendarEvents.recordSyncedValue(
          event,
          remoteId: remoteId,
          lastModified: lastModified
        )
      }
      state.calendarEvents.recordDateRange(
        SyncDateRange(start: event.startDate, end: event.endDate),
        for: remoteId
      )
    }

    try SyncConfigStore.saveIdMapping(idMapping)
    try SyncConfigStore.saveState(state)
    return result
  }

  func pushLists() async throws -> PushResult {
    let lists = try await listService.fetchLists()
    var idMapping = SyncConfigStore.loadIdMapping()
    var state = SyncConfigStore.loadState()
    let localToRemote = invertMapping(idMapping.reminderLists)
    let currentRemoteIds = Set(lists.map { localToRemote[$0.id] ?? $0.id })
    let deletedRemoteIds = state.reminderLists.deletionCandidates(
      currentRemoteIds: currentRemoteIds)
    let fallbackLastModified = DateFormatter.eventISO8601.string(from: Date())
    let lastModifiedByRemoteId = try Dictionary(
      uniqueKeysWithValues: lists.map { list in
        let remoteId = localToRemote[list.id] ?? list.id
        return (
          remoteId,
          try state.reminderLists.lastModified(
            for: list,
            remoteId: remoteId,
            fallback: fallbackLastModified
          )
        )
      }
    )

    let result = try await syncClient.pushLists(
      lists,
      idOverrides: localToRemote,
      lastModifiedByRemoteId: lastModifiedByRemoteId
    )

    for remoteId in deletedRemoteIds {
      try await syncClient.deleteList(
        id: remoteId, lastModified: state.reminderLists.lastModifiedByRemoteId[remoteId])
      idMapping.reminderLists.removeValue(forKey: remoteId)
      state.reminderLists.removeRemoteId(remoteId)
    }

    for list in lists {
      let remoteId = localToRemote[list.id] ?? list.id
      if let lastModified = lastModifiedByRemoteId[remoteId] {
        try state.reminderLists.recordSyncedValue(
          list,
          remoteId: remoteId,
          lastModified: lastModified
        )
      }
    }

    try SyncConfigStore.saveIdMapping(idMapping)
    try SyncConfigStore.saveState(state)
    return result
  }

  // MARK: - Pull

  func pullReminders() async throws -> PullSummary {
    let localReminders = try await reminderService.fetchReminders(showCompleted: true)
    let localLastModified = lastModifiedIndex(
      localReminders.map { (id: $0.id, lastModified: $0.lastModifiedDate) })

    return try await pullEntities(
      entityName: "reminders",
      localLastModifiedById: localLastModified,
      pull: { cursor in try await self.syncClient.pullReminders(cursor: cursor) },
      getCursor: { $0.reminders },
      setCursor: { $0.reminders = $1 },
      getMapping: { $0.reminders },
      setMapping: { mapping, key, value in
        if let value {
          mapping.reminders[key] = value
        } else {
          mapping.reminders.removeValue(forKey: key)
        }
      },
      getEntityState: { $0.reminders },
      setEntityState: { $0.reminders = $1 },
      applyDelete: { localId in
        try await self.reminderService.deleteReminder(id: localId)
      },
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
        } catch let error as EventCLIError where self.isNotFoundError(error) {
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
      }
    )
  }

  func pullEvents() async throws -> PullSummary {
    let window = eventSyncWindow()
    let localEvents = try await calendarService.fetchEvents(
      startDate: window.start,
      endDate: window.end
    )
    let localLastModified = lastModifiedIndex(
      localEvents.map { (id: $0.id, lastModified: $0.lastModifiedDate) })

    return try await pullEntities(
      entityName: "calendar events",
      localLastModifiedById: localLastModified,
      pull: { cursor in try await self.syncClient.pullEvents(cursor: cursor) },
      getCursor: { $0.calendarEvents },
      setCursor: { $0.calendarEvents = $1 },
      getMapping: { $0.calendarEvents },
      setMapping: { mapping, key, value in
        if let value {
          mapping.calendarEvents[key] = value
        } else {
          mapping.calendarEvents.removeValue(forKey: key)
        }
      },
      getEntityState: { $0.calendarEvents },
      setEntityState: { $0.calendarEvents = $1 },
      applyDelete: { localId in
        try await self.calendarService.deleteEvent(id: localId)
      },
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
        } catch let error as EventCLIError where self.isNotFoundError(error) {
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
      }
    )
  }

  func pullLists() async throws -> PullSummary {
    // Reminder lists carry no modification timestamp, so the pull always
    // applies the server value (an empty conflict index disables the guard).
    try await pullEntities(
      entityName: "reminder lists",
      localLastModifiedById: [:],
      pull: { cursor in try await self.syncClient.pullLists(cursor: cursor) },
      getCursor: { $0.reminderLists },
      setCursor: { $0.reminderLists = $1 },
      getMapping: { $0.reminderLists },
      setMapping: { mapping, key, value in
        if let value {
          mapping.reminderLists[key] = value
        } else {
          mapping.reminderLists.removeValue(forKey: key)
        }
      },
      getEntityState: { $0.reminderLists },
      setEntityState: { $0.reminderLists = $1 },
      applyDelete: { localId in
        try await self.listService.deleteList(id: localId)
      },
      applyUpsert: { localId, item in
        do {
          _ = try await self.listService.updateList(id: localId, name: item.data.title)
          return nil
        } catch let error as EventCLIError where self.isNotFoundError(error) {
          let created = try await self.listService.createList(name: item.data.title)
          return created.id
        }
      }
    )
  }

  // MARK: - Generic Pull Loop

  private func pullEntities<T: Codable & Sendable>(
    entityName: String,
    localLastModifiedById: [String: String],
    pull: (String?) async throws -> PullResponse<T>,
    getCursor: (SyncCursors) -> String?,
    setCursor: (inout SyncCursors, String?) -> Void,
    getMapping: (SyncIdMapping) -> [String: String],
    setMapping: (inout SyncIdMapping, String, String?) -> Void,
    getEntityState: (SyncState) -> SyncEntityState,
    setEntityState: (inout SyncState, SyncEntityState) -> Void,
    applyDelete: (String) async throws -> Void,
    applyUpsert: (String, PullItem<T>) async throws -> String?
  ) async throws -> PullSummary {
    var cursors = SyncConfigStore.loadCursors()
    var idMapping = SyncConfigStore.loadIdMapping()
    var state = SyncConfigStore.loadState()
    var entityState = getEntityState(state)
    var pulled = 0
    var deleted = 0
    var skipped = 0
    var hasMore = true

    func persist() throws {
      setEntityState(&state, entityState)
      try SyncConfigStore.saveCursors(cursors)
      try SyncConfigStore.saveIdMapping(idMapping)
      try SyncConfigStore.saveState(state)
    }

    while hasMore {
      let response: PullResponse<T>
      do {
        response = try await pull(getCursor(cursors))
      } catch {
        // Persist progress from earlier pages so created items keep their ID
        // mapping; otherwise a retry would create duplicate local entities.
        try? persist()
        throw error
      }
      hasMore = response.hasMore
      var hadFailures = false

      for item in response.items {
        let localId = getMapping(idMapping)[item.id] ?? item.id

        if item.deleted {
          do {
            try await applyDelete(localId)
          } catch let error as EventCLIError where isNotFoundError(error) {
            // Already gone locally, clean up mapping
          } catch {
            fputs("Warning: Could not delete \(entityName) \(item.id): \(error)\n", stderr)
            hadFailures = true
            continue
          }
          setMapping(&idMapping, item.id, nil)
          entityState.removeRemoteId(item.id)
          deleted += 1
          continue
        }

        // Conflict guard: never overwrite a local copy that was modified more
        // recently than the server's version -- it is pushed on the next sync.
        if let localValue = localLastModifiedById[localId],
          let localModified = SyncTimestamp.parse(localValue),
          let serverModified = SyncTimestamp.parse(item.lastModified),
          localModified > serverModified
        {
          fputs(
            "Skipped \(entityName) \(item.id): local copy is newer; it will be pushed on next sync\n",
            stderr)
          skipped += 1
          continue
        }

        do {
          let newLocalId = try await applyUpsert(localId, item)
          if let newLocalId {
            setMapping(&idMapping, item.id, newLocalId)
          }
          try entityState.recordSyncedValue(
            item.data,
            remoteId: item.id,
            lastModified: item.lastModified
          )
          pulled += 1
        } catch {
          fputs("Warning: Could not sync \(entityName) \(item.id): \(error)\n", stderr)
          hadFailures = true
        }
      }

      setCursor(
        &cursors,
        SyncCursorPolicy.nextCursor(
          currentCursor: getCursor(cursors),
          responseCursor: response.cursor,
          hadFailures: hadFailures
        )
      )
      // Persist after every page so a later network failure cannot strand
      // already-applied items without their ID mapping.
      try persist()

      if hadFailures {
        throw EventCLIError.unknown(
          "Pull \(entityName) failed for one or more items. Cursor was not advanced."
        )
      }
    }

    return PullSummary(pulled: pulled, deleted: deleted, skipped: skipped)
  }

  // MARK: - Helpers

  /// The calendar window synced by push and pull: one year back to two years ahead.
  private nonisolated func eventSyncWindow() -> (start: String, end: String) {
    let start = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    let end = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return (formatter.string(from: start), formatter.string(from: end))
  }

  /// Builds a `localId -> lastModified` index, dropping entries without a timestamp.
  private nonisolated func lastModifiedIndex(
    _ pairs: [(id: String, lastModified: String?)]
  ) -> [String: String] {
    var index: [String: String] = [:]
    for pair in pairs {
      if let lastModified = pair.lastModified {
        index[pair.id] = lastModified
      }
    }
    return index
  }

  private func ensureReminderListExists(named listName: String) async throws {
    let normalizedName = listName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedName.isEmpty else {
      return
    }

    let existingLists = try await listService.fetchLists()
    guard existingLists.contains(where: { $0.title == normalizedName }) == false else {
      return
    }

    _ = try await listService.createList(name: normalizedName)
  }

  private func isNotFoundError(_ error: EventCLIError) -> Bool {
    if case .notFound = error {
      return true
    }
    return false
  }

  private nonisolated func invertMapping(_ mapping: [String: String]) -> [String: String] {
    let result = SyncIdMapping.inverted(mapping)
    for collision in result.collisions {
      fputs(
        "Warning: duplicate ID mapping -- local '\(collision.localId)' maps to both "
          + "'\(collision.keptRemoteId)' and '\(collision.droppedRemoteId)'\n",
        stderr)
    }
    return result.mapping
  }
}

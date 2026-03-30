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
    let idMapping = SyncConfigStore.loadIdMapping()
    let localToRemote = Dictionary(
      idMapping.reminders.map { ($0.value, $0.key) },
      uniquingKeysWith: { first, _ in first }
    )
    return try await syncClient.pushReminders(reminders, idOverrides: localToRemote)
  }

  func pushEvents() async throws -> PushResult {
    let start = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    let end = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let events = try await calendarService.fetchEvents(
      startDate: formatter.string(from: start),
      endDate: formatter.string(from: end)
    )
    let idMapping = SyncConfigStore.loadIdMapping()
    let localToRemote = Dictionary(
      idMapping.calendarEvents.map { ($0.value, $0.key) },
      uniquingKeysWith: { first, _ in first }
    )
    return try await syncClient.pushEvents(events, idOverrides: localToRemote)
  }

  func pushLists() async throws -> PushResult {
    let lists = try await listService.fetchLists()
    let idMapping = SyncConfigStore.loadIdMapping()
    let localToRemote = Dictionary(
      idMapping.reminderLists.map { ($0.value, $0.key) },
      uniquingKeysWith: { first, _ in first }
    )
    return try await syncClient.pushLists(lists, idOverrides: localToRemote)
  }

  // MARK: - Pull

  func pullReminders() async throws -> PullSummary {
    var cursors = SyncConfigStore.loadCursors()
    var idMapping = SyncConfigStore.loadIdMapping()
    var pulled = 0
    var deleted = 0
    var hasMore = true

    while hasMore {
      let response = try await syncClient.pullReminders(cursor: cursors.reminders)
      hasMore = response.hasMore
      var hadFailures = false

      for item in response.items {
        let localId = idMapping.reminders[item.id] ?? item.id

        if item.deleted {
          do {
            try await reminderService.deleteReminder(id: localId)
            idMapping.reminders.removeValue(forKey: item.id)
            deleted += 1
          } catch let error as EventCLIError where isNotFoundError(error) {
            idMapping.reminders.removeValue(forKey: item.id)
            deleted += 1
          } catch {
            print("Warning: Could not delete reminder \(item.id): \(error)")
            hadFailures = true
          }
        } else {
          do {
            _ = try await reminderService.updateReminder(
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
            pulled += 1
          } catch let error as EventCLIError where isNotFoundError(error) {
            do {
              let created = try await reminderService.createReminder(
                title: item.data.title,
                listName: item.data.list,
                notes: item.data.notes,
                url: item.data.url,
                dueDate: item.data.dueDate,
                priority: item.data.priority,
                useShortcuts: false
              )
              if item.data.isCompleted || item.data.startDate != nil {
                _ = try await reminderService.updateReminder(
                  id: created.id,
                  completed: item.data.isCompleted,
                  startDate: item.data.startDate,
                  useShortcuts: false
                )
              }
              idMapping.reminders[item.id] = created.id
              pulled += 1
            } catch {
              print("Warning: Could not create reminder \(item.id): \(error)")
              hadFailures = true
            }
          } catch {
            print("Warning: Could not update reminder \(item.id): \(error)")
            hadFailures = true
          }
        }
      }

      cursors.reminders = SyncCursorPolicy.nextCursor(
        currentCursor: cursors.reminders,
        responseCursor: response.cursor,
        hadFailures: hadFailures
      )
      if hadFailures {
        try SyncConfigStore.saveCursors(cursors)
        try SyncConfigStore.saveIdMapping(idMapping)
        throw EventCLIError.unknown(
          "Pull reminders failed for one or more items. Cursor was not advanced."
        )
      }
    }

    try SyncConfigStore.saveCursors(cursors)
    try SyncConfigStore.saveIdMapping(idMapping)
    return PullSummary(pulled: pulled, deleted: deleted)
  }

  func pullEvents() async throws -> PullSummary {
    var cursors = SyncConfigStore.loadCursors()
    var idMapping = SyncConfigStore.loadIdMapping()
    var pulled = 0
    var deleted = 0
    var hasMore = true

    while hasMore {
      let response = try await syncClient.pullEvents(cursor: cursors.calendarEvents)
      hasMore = response.hasMore
      var hadFailures = false

      for item in response.items {
        let localId = idMapping.calendarEvents[item.id] ?? item.id

        if item.deleted {
          do {
            try await calendarService.deleteEvent(id: localId)
            idMapping.calendarEvents.removeValue(forKey: item.id)
            deleted += 1
          } catch let error as EventCLIError where isNotFoundError(error) {
            idMapping.calendarEvents.removeValue(forKey: item.id)
            deleted += 1
          } catch {
            print("Warning: Could not delete event \(item.id): \(error)")
            hadFailures = true
          }
        } else {
          do {
            _ = try await calendarService.updateEvent(
              id: localId,
              title: item.data.title,
              startDate: item.data.startDate,
              endDate: item.data.endDate,
              location: item.data.location,
              notes: item.data.notes,
              url: item.data.url
            )
            pulled += 1
          } catch let error as EventCLIError where isNotFoundError(error) {
            do {
              let created = try await calendarService.createEvent(
                title: item.data.title,
                startDate: item.data.startDate,
                endDate: item.data.endDate,
                calendarName: item.data.calendar,
                location: item.data.location,
                notes: item.data.notes,
                url: item.data.url
              )
              idMapping.calendarEvents[item.id] = created.id
              pulled += 1
            } catch {
              print("Warning: Could not create event \(item.id): \(error)")
              hadFailures = true
            }
          } catch {
            print("Warning: Could not update event \(item.id): \(error)")
            hadFailures = true
          }
        }
      }

      cursors.calendarEvents = SyncCursorPolicy.nextCursor(
        currentCursor: cursors.calendarEvents,
        responseCursor: response.cursor,
        hadFailures: hadFailures
      )
      if hadFailures {
        try SyncConfigStore.saveCursors(cursors)
        try SyncConfigStore.saveIdMapping(idMapping)
        throw EventCLIError.unknown(
          "Pull calendar events failed for one or more items. Cursor was not advanced."
        )
      }
    }

    try SyncConfigStore.saveCursors(cursors)
    try SyncConfigStore.saveIdMapping(idMapping)
    return PullSummary(pulled: pulled, deleted: deleted)
  }

  func pullLists() async throws -> PullSummary {
    var cursors = SyncConfigStore.loadCursors()
    var idMapping = SyncConfigStore.loadIdMapping()
    var pulled = 0
    var deleted = 0
    var hasMore = true

    while hasMore {
      let response = try await syncClient.pullLists(cursor: cursors.reminderLists)
      hasMore = response.hasMore
      var hadFailures = false

      for item in response.items {
        let localId = idMapping.reminderLists[item.id] ?? item.id

        if item.deleted {
          do {
            try await listService.deleteList(id: localId)
            idMapping.reminderLists.removeValue(forKey: item.id)
            deleted += 1
          } catch let error as EventCLIError where isNotFoundError(error) {
            idMapping.reminderLists.removeValue(forKey: item.id)
            deleted += 1
          } catch {
            print("Warning: Could not delete list \(item.id): \(error)")
            hadFailures = true
          }
        } else {
          do {
            _ = try await listService.updateList(id: localId, name: item.data.title)
            pulled += 1
          } catch let error as EventCLIError where isNotFoundError(error) {
            do {
              let created = try await listService.createList(name: item.data.title)
              idMapping.reminderLists[item.id] = created.id
              pulled += 1
            } catch {
              print("Warning: Could not create list \(item.id): \(error)")
              hadFailures = true
            }
          } catch {
            print("Warning: Could not update list \(item.id): \(error)")
            hadFailures = true
          }
        }
      }

      cursors.reminderLists = SyncCursorPolicy.nextCursor(
        currentCursor: cursors.reminderLists,
        responseCursor: response.cursor,
        hadFailures: hadFailures
      )
      if hadFailures {
        try SyncConfigStore.saveCursors(cursors)
        try SyncConfigStore.saveIdMapping(idMapping)
        throw EventCLIError.unknown(
          "Pull reminder lists failed for one or more items. Cursor was not advanced."
        )
      }
    }

    try SyncConfigStore.saveCursors(cursors)
    try SyncConfigStore.saveIdMapping(idMapping)
    return PullSummary(pulled: pulled, deleted: deleted)
  }

  private func isNotFoundError(_ error: EventCLIError) -> Bool {
    if case .notFound = error {
      return true
    }
    return false
  }
}

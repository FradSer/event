import EventCommands
import EventKit
import EventModels
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

  // MARK: - Push

  func pushReminders() async throws -> PushResult {
    let reminders = try await reminderService.fetchReminders(showCompleted: true)
    return try await syncClient.pushReminders(reminders)
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
    return try await syncClient.pushEvents(events)
  }

  func pushLists() async throws -> PushResult {
    let lists = try await listService.fetchLists()
    return try await syncClient.pushLists(lists)
  }

  // MARK: - Pull

  func pullReminders() async throws -> PullSummary {
    var cursors = SyncConfigStore.loadCursors()
    var pulled = 0
    var deleted = 0
    var hasMore = true

    while hasMore {
      let response = try await syncClient.pullReminders(cursor: cursors.reminders)
      hasMore = response.hasMore

      for item in response.items {
        if item.deleted {
          do {
            try await reminderService.deleteReminder(id: item.id)
            deleted += 1
          } catch {
            print("Warning: Could not delete reminder \(item.id): \(error)")
          }
        } else {
          do {
            _ = try await reminderService.updateReminder(
              id: item.id,
              title: item.data.title,
              completed: item.data.isCompleted,
              notes: item.data.notes,
              dueDate: item.data.dueDate,
              startDate: item.data.startDate,
              priority: item.data.priority,
              useShortcuts: false
            )
            pulled += 1
          } catch {
            // Not found locally -- create new
            do {
              _ = try await reminderService.createReminder(
                title: item.data.title,
                listName: item.data.list,
                notes: item.data.notes,
                dueDate: item.data.dueDate,
                priority: item.data.priority,
                useShortcuts: false
              )
              pulled += 1
            } catch {
              print("Warning: Could not sync reminder \(item.id): \(error)")
            }
          }
        }
      }

      cursors.reminders = response.cursor
    }

    try SyncConfigStore.saveCursors(cursors)
    return PullSummary(pulled: pulled, deleted: deleted)
  }

  func pullEvents() async throws -> PullSummary {
    var cursors = SyncConfigStore.loadCursors()
    var pulled = 0
    var deleted = 0
    var hasMore = true

    while hasMore {
      let response = try await syncClient.pullEvents(cursor: cursors.calendarEvents)
      hasMore = response.hasMore

      for item in response.items {
        if item.deleted {
          do {
            try await calendarService.deleteEvent(id: item.id)
            deleted += 1
          } catch {
            print("Warning: Could not delete event \(item.id): \(error)")
          }
        } else {
          do {
            _ = try await calendarService.updateEvent(
              id: item.id,
              title: item.data.title,
              startDate: item.data.startDate,
              endDate: item.data.endDate,
              location: item.data.location,
              notes: item.data.notes
            )
            pulled += 1
          } catch {
            do {
              _ = try await calendarService.createEvent(
                title: item.data.title,
                startDate: item.data.startDate,
                endDate: item.data.endDate,
                location: item.data.location,
                notes: item.data.notes
              )
              pulled += 1
            } catch {
              print("Warning: Could not sync event \(item.id): \(error)")
            }
          }
        }
      }

      cursors.calendarEvents = response.cursor
    }

    try SyncConfigStore.saveCursors(cursors)
    return PullSummary(pulled: pulled, deleted: deleted)
  }

  func pullLists() async throws -> PullSummary {
    var cursors = SyncConfigStore.loadCursors()
    var pulled = 0
    var deleted = 0
    var hasMore = true

    while hasMore {
      let response = try await syncClient.pullLists(cursor: cursors.reminderLists)
      hasMore = response.hasMore

      for item in response.items {
        if item.deleted {
          do {
            try await listService.deleteList(id: item.id)
            deleted += 1
          } catch {
            print("Warning: Could not delete list \(item.id): \(error)")
          }
        } else {
          do {
            _ = try await listService.updateList(id: item.id, name: item.data.title)
            pulled += 1
          } catch {
            do {
              _ = try await listService.createList(name: item.data.title)
              pulled += 1
            } catch {
              print("Warning: Could not sync list \(item.id): \(error)")
            }
          }
        }
      }

      cursors.reminderLists = response.cursor
    }

    try SyncConfigStore.saveCursors(cursors)
    return PullSummary(pulled: pulled, deleted: deleted)
  }
}

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
                    deleted += 1
                } else {
                    pulled += 1
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
                    deleted += 1
                } else {
                    pulled += 1
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
                    deleted += 1
                } else {
                    pulled += 1
                }
            }

            cursors.reminderLists = response.cursor
        }

        try SyncConfigStore.saveCursors(cursors)
        return PullSummary(pulled: pulled, deleted: deleted)
    }
}

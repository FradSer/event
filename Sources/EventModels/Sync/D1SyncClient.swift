import AsyncHTTPClient
import Foundation
import NIOCore
import NIOFoundationCompat

// MARK: - D1 Sync Client

public actor D1SyncClient {
    private let config: SyncConfig
    private let httpClient: HTTPClient

    public init(config: SyncConfig) {
        self.config = config
        self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
    }

    deinit {
        try? httpClient.syncShutdown()
    }

    // MARK: - Reminders

    public func pushReminders(_ reminders: [Reminder]) async throws -> PushResult {
        let items = reminders.map { reminder in
            PushRequestItem(
                id: reminder.id,
                data: reminder,
                lastModified: reminder.lastModifiedDate ?? "1970-01-01 00:00:00"
            )
        }
        return try await push(entity: "reminders", items: items)
    }

    public func pullReminders(cursor: String?) async throws -> PullResponse<Reminder> {
        return try await pull(entity: "reminders", cursor: cursor)
    }

    // MARK: - Calendar Events

    public func pushEvents(_ events: [CalendarEvent]) async throws -> PushResult {
        let items = events.map { event in
            PushRequestItem(
                id: event.id,
                data: event,
                lastModified: event.lastModifiedDate ?? "1970-01-01 00:00:00"
            )
        }
        return try await push(entity: "calendar_events", items: items)
    }

    public func pullEvents(cursor: String?) async throws -> PullResponse<CalendarEvent> {
        return try await pull(entity: "calendar_events", cursor: cursor)
    }

    // MARK: - Reminder Lists

    public func pushLists(_ lists: [ReminderList]) async throws -> PushResult {
        let items = lists.map { list in
            PushRequestItem(id: list.id, data: list, lastModified: "1970-01-01 00:00:00")
        }
        return try await push(entity: "reminder_lists", items: items)
    }

    public func pullLists(cursor: String?) async throws -> PullResponse<ReminderList> {
        return try await pull(entity: "reminder_lists", cursor: cursor)
    }

    // MARK: - Delete

    public func deleteReminder(id: String) async throws {
        try await delete(entity: "reminders", id: id)
    }

    public func deleteEvent(id: String) async throws {
        try await delete(entity: "calendar_events", id: id)
    }

    public func deleteList(id: String) async throws {
        try await delete(entity: "reminder_lists", id: id)
    }

    // MARK: - Generic HTTP Methods

    private func push<T: Codable>(entity: String, items: [PushRequestItem<T>]) async throws -> PushResult {
        let request = PushRequest(deviceId: config.deviceId, items: items)
        let body = try JSONEncoder().encode(request)

        var httpRequest = HTTPClientRequest(url: "\(config.apiURL)/api/v1/\(entity)/push")
        httpRequest.method = .POST
        httpRequest.headers.add(name: "Authorization", value: "Bearer \(config.apiToken)")
        httpRequest.headers.add(name: "Content-Type", value: "application/json")
        httpRequest.body = .bytes(body)

        let response = try await httpClient.execute(httpRequest, timeout: .seconds(30))
        let responseData = try await response.body.collect(upTo: 1024 * 1024)

        guard response.status == .ok else {
            let errorBody = String(buffer: responseData)
            throw EventCLIError.unknown("Push failed (\(response.status.code)): \(errorBody)")
        }

        return try JSONDecoder().decode(PushResult.self, from: Data(buffer: responseData))
    }

    private func pull<T: Codable>(entity: String, cursor: String?) async throws -> PullResponse<T> {
        let cursorParam = cursor.map { "?cursor=\($0)" } ?? ""
        var httpRequest = HTTPClientRequest(
            url: "\(config.apiURL)/api/v1/\(entity)/pull\(cursorParam)"
        )
        httpRequest.method = .GET
        httpRequest.headers.add(name: "Authorization", value: "Bearer \(config.apiToken)")

        let response = try await httpClient.execute(httpRequest, timeout: .seconds(30))
        let responseData = try await response.body.collect(upTo: 10 * 1024 * 1024)

        guard response.status == .ok else {
            let errorBody = String(buffer: responseData)
            throw EventCLIError.unknown("Pull failed (\(response.status.code)): \(errorBody)")
        }

        let dto = try JSONDecoder().decode(PullResponseDTO.self, from: Data(buffer: responseData))

        let items: [PullItem<T>] = dto.items.compactMap { itemDTO in
            guard let jsonData = try? JSONSerialization.data(withJSONObject: itemDTO.data.value),
                let decoded = try? JSONDecoder().decode(T.self, from: jsonData)
            else {
                return nil
            }
            return PullItem(
                id: itemDTO.id,
                data: decoded,
                deleted: itemDTO.deleted,
                updatedAt: itemDTO.updatedAt
            )
        }

        return PullResponse(items: items, cursor: dto.cursor, hasMore: dto.hasMore)
    }

    private func delete(entity: String, id: String) async throws {
        var httpRequest = HTTPClientRequest(url: "\(config.apiURL)/api/v1/\(entity)/\(id)")
        httpRequest.method = .DELETE
        httpRequest.headers.add(name: "Authorization", value: "Bearer \(config.apiToken)")

        let response = try await httpClient.execute(httpRequest, timeout: .seconds(30))
        guard response.status == .ok else {
            throw EventCLIError.unknown("Delete failed (\(response.status.code))")
        }
    }
}

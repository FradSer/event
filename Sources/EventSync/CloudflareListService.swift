import AppleSyncKit
import EventModels
import Foundation

// MARK: - Cloudflare List Service

public actor CloudflareListService: ListsBackend {
  private let client: D1SyncClient

  public init(client: D1SyncClient) {
    self.client = client
  }

  public func fetchLists() async throws -> [ReminderList] {
    try await client.pullAll(entity: "reminder_lists")
  }

  public func createList(title: String, color: String?) async throws -> ReminderList {
    let list = ReminderList(
      id: UUID().uuidString,
      title: title,
      color: color,
      isImmutable: false
    )
    _ = try await client.push(entity: "reminder_lists", items: [list], id: { $0.id })
    return list
  }

  public func deleteList(id: String) async throws {
    try await client.delete(
      entity: "reminder_lists", id: id,
      lastModified: ISO8601DateFormatter.syncISO8601.string(from: Date()))
  }

  public func updateList(id: String, title: String?, color: String?) async throws -> ReminderList {
    let lists: [ReminderList] = try await client.pullAll(entity: "reminder_lists")
    guard let existing = lists.first(where: { $0.id == id }) else {
      throw EventCLIError.notFound("List with ID '\(id)' not found")
    }
    let updated = ReminderList(
      id: existing.id,
      title: title ?? existing.title,
      color: color ?? existing.color,
      isImmutable: existing.isImmutable
    )
    _ = try await client.push(entity: "reminder_lists", items: [updated], id: { $0.id })
    return updated
  }
}

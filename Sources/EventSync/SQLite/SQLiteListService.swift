import AppleSyncKit
import EventModels
import Foundation
import SQLite

// MARK: - SQLite List Service

public actor SQLiteListService: ListsBackend {
  private let connection: Connection

  public init(connection: Connection) {
    self.connection = connection
  }

  public func fetchLists() async throws -> [ReminderList] {
    let sql = "SELECT data FROM reminder_lists WHERE deleted = 0"
    return try connection.prepare(sql).map { row in
      try Self.decodeList(from: row[0])
    }.sorted { $0.title < $1.title }
  }

  public func createList(title: String, color: String?) async throws -> ReminderList {
    let list = ReminderList(
      id: UUID().uuidString,
      title: title,
      color: color,
      isImmutable: false
    )

    let now = ISO8601DateFormatter.syncISO8601.string(from: Date())
    let jsonString = try Self.encode(list)

    try connection.run(
      """
      INSERT INTO reminder_lists (id, data, last_modified, deleted, updated_at, is_local_only)
      VALUES (?, ?, ?, 0, NULL, 1)
      """,
      list.id, jsonString, now
    )

    return list
  }

  public func deleteList(id: String) async throws {
    try connection.run(
      "UPDATE reminder_lists SET deleted = 1, is_local_only = 1 WHERE id = ?",
      id
    )

    if connection.changes == 0 {
      throw EventCLIError.notFound("List with ID '\(id)' not found")
    }
  }

  public func updateList(id: String, title: String?, color: String?) async throws -> ReminderList {
    let sql = "SELECT data FROM reminder_lists WHERE id = ?"
    var existing: ReminderList?
    for row in try connection.prepare(sql, [id]) {
      existing = try Self.decodeList(from: row[0])
      break
    }
    guard var list = existing else {
      throw EventCLIError.notFound("List with ID '\(id)' not found")
    }

    if let title = title {
      list = ReminderList(
        id: list.id, title: title, color: list.color, isImmutable: list.isImmutable)
    }
    if let color = color {
      list = ReminderList(
        id: list.id, title: list.title, color: color, isImmutable: list.isImmutable)
    }

    let now = ISO8601DateFormatter.syncISO8601.string(from: Date())
    let jsonString = try Self.encode(list)

    try connection.run(
      "UPDATE reminder_lists SET data = ?, last_modified = ?, is_local_only = 1 WHERE id = ?",
      jsonString, now, id
    )

    return list
  }

  // MARK: - Private Helpers

  private static func decodeList(from value: Binding?) throws -> ReminderList {
    guard let jsonString = value as? String,
      let jsonData = jsonString.data(using: .utf8)
    else {
      throw EventCLIError.unknown("Failed to decode reminder list data")
    }
    return try JSONDecoder().decode(ReminderList.self, from: jsonData)
  }

  private static func encode(_ list: ReminderList) throws -> String {
    let data = try JSONEncoder().encode(list)
    guard let jsonString = String(data: data, encoding: .utf8) else {
      throw EventCLIError.unknown("Failed to encode reminder list to JSON")
    }
    return jsonString
  }
}

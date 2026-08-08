import AppleSyncKit
import EventModels
import Foundation
import SQLite

// MARK: - SQLite Reminder Service

/// SQLite-backed reminder storage using SQLite.swift. Stores each Reminder as JSON in a `data` column
/// and tracks sync state via `is_local_only` and `deleted` flags.
public actor SQLiteReminderService: RemindersBackend {
  private let connection: Connection

  public init(connection: Connection) {
    self.connection = connection
  }

  // MARK: - Fetch

  public func fetchReminders(
    listName: String?,
    showCompleted: Bool
  ) async throws -> [Reminder] {
    var sql = "SELECT data FROM reminders WHERE deleted = 0"
    var bindings: [Binding?] = []

    if let listName {
      sql += " AND json_extract(data, '$.list') = ?"
      bindings.append(listName)
    }

    if !showCompleted {
      sql += " AND json_extract(data, '$.isCompleted') = 0"
    }

    sql += " ORDER BY updated_at DESC"

    return try connection.prepare(sql, bindings).map { row in
      try Self.decodeReminder(from: row[0])
    }
  }

  public func fetchReminder(byId id: String) async throws -> Reminder {
    let sql = "SELECT data FROM reminders WHERE id = ? AND deleted = 0"
    for row in try connection.prepare(sql, [id]) {
      return try Self.decodeReminder(from: row[0])
    }
    throw EventCLIError.notFound("Reminder with ID '\(id)' not found")
  }

  // MARK: - Create

  public func createReminder(_ params: CreateReminderParams) async throws -> Reminder {
    let now = ISO8601DateFormatter.syncISO8601.string(from: Date())
    let id = UUID().uuidString

    let reminder = Reminder(
      id: id,
      title: params.title,
      isCompleted: false,
      isFlagged: false,
      list: params.listName ?? "Reminders",
      notes: params.notes,
      url: params.url,
      location: nil,
      timeZone: TimeZone.current.identifier,
      dueDate: params.dueDate,
      startDate: params.startDate,
      completionDate: nil,
      creationDate: now,
      lastModifiedDate: now,
      externalId: nil,
      priority: params.priority,
      alarms: nil,
      recurrenceRules: nil,
      locationTrigger: nil
    )

    let jsonString = try Self.encode(reminder)

    try connection.run(
      """
      INSERT INTO reminders (id, data, last_modified, deleted, updated_at, is_local_only)
      VALUES (?, ?, ?, 0, NULL, 1)
      """,
      id, jsonString, now
    )

    return reminder
  }

  // MARK: - Update

  public func updateReminder(
    id: String,
    params: UpdateReminderParams
  ) async throws -> Reminder {
    let existing = try await fetchReminder(byId: id)
    let now = ISO8601DateFormatter.syncISO8601.string(from: Date())

    let updated = Reminder(
      id: existing.id,
      title: params.title ?? existing.title,
      isCompleted: params.completed ?? existing.isCompleted,
      isFlagged: existing.isFlagged,
      list: existing.list,
      notes: params.notes ?? existing.notes,
      url: params.url ?? existing.url,
      location: existing.location,
      timeZone: existing.timeZone,
      dueDate: params.clearDue ? nil : (params.dueDate ?? existing.dueDate),
      startDate: params.clearStart ? nil : (params.startDate ?? existing.startDate),
      completionDate: (params.completed ?? existing.isCompleted)
        ? (existing.completionDate ?? now) : nil,
      creationDate: existing.creationDate,
      lastModifiedDate: now,
      externalId: existing.externalId,
      priority: params.priority ?? existing.priority,
      alarms: existing.alarms,
      recurrenceRules: existing.recurrenceRules,
      locationTrigger: existing.locationTrigger
    )

    let jsonString = try Self.encode(updated)

    try connection.run(
      """
      UPDATE reminders
      SET data = ?, last_modified = ?, updated_at = NULL, is_local_only = 1
      WHERE id = ? AND deleted = 0
      """,
      jsonString, now, id
    )

    return updated
  }

  // MARK: - Delete

  public func deleteReminder(id: String) async throws {
    let now = ISO8601DateFormatter.syncISO8601.string(from: Date())
    try connection.run(
      """
      UPDATE reminders
      SET deleted = 1, last_modified = ?, updated_at = NULL, is_local_only = 1
      WHERE id = ? AND deleted = 0
      """,
      now, id
    )

    if connection.changes == 0 {
      throw EventCLIError.notFound("Reminder with ID '\(id)' not found")
    }
  }

  // MARK: - Private Helpers

  private static func decodeReminder(from value: Binding?) throws -> Reminder {
    guard let jsonString = value as? String,
      let jsonData = jsonString.data(using: .utf8)
    else {
      throw EventCLIError.unknown("Failed to decode reminder data")
    }
    return try JSONDecoder().decode(Reminder.self, from: jsonData)
  }

  private static func encode(_ reminder: Reminder) throws -> String {
    let jsonData = try JSONEncoder().encode(reminder)
    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
      throw EventCLIError.unknown("Failed to encode reminder as JSON")
    }
    return jsonString
  }
}

import AppleSyncKit
import EventModels
import Foundation

// MARK: - Cloudflare Reminder Service

/// Reads and writes reminders directly against Cloudflare D1, transparently
/// decrypting sensitive fields on read and encrypting on write via
/// `EventEncryptor`. Used by the advanced `event sync reminders` subcommands to
/// inspect or seed the cloud store without touching EventKit or local SQLite.
public actor CloudflareReminderService: RemindersBackend {
  private let client: D1SyncClient
  private let encryptor: EventEncryptor

  public init(client: D1SyncClient, encryptor: EventEncryptor) {
    self.client = client
    self.encryptor = encryptor
  }

  // MARK: - Fetch

  public func fetchReminders(
    listName: String?,
    showCompleted: Bool
  ) async throws -> [Reminder] {
    let all: [Reminder] = try await client.pullAll(entity: "reminders")
    var filtered = all
    if let listName {
      filtered = filtered.filter { $0.list == listName }
    }
    if !showCompleted {
      filtered = filtered.filter { !$0.isCompleted }
    }
    return try await encryptor.decryptReminders(filtered)
  }

  public func fetchReminder(byId id: String) async throws -> Reminder {
    let all: [Reminder] = try await client.pullAll(entity: "reminders")
    guard let reminder = all.first(where: { $0.id == id }) else {
      throw EventCLIError.notFound("Reminder with ID '\(id)' not found")
    }
    return try await encryptor.decryptReminders([reminder])[0]
  }

  // MARK: - Create

  public func createReminder(_ params: CreateReminderParams) async throws -> Reminder {
    let now = ISO8601DateFormatter.syncISO8601.string(from: Date())
    let id = UUID().uuidString

    let listName = params.listName ?? "Reminders"
    let plainReminder = Reminder(
      id: id,
      title: params.title,
      isCompleted: false,
      isFlagged: false,
      list: listName,
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

    let d1Reminders = try await encryptor.encryptReminders([plainReminder])
    _ = try await client.push(entity: "reminders", items: d1Reminders, id: { $0.id })
    return plainReminder
  }

  // MARK: - Update

  public func updateReminder(
    id: String,
    params: UpdateReminderParams
  ) async throws -> Reminder {
    let all: [Reminder] = try await client.pullAll(entity: "reminders")
    guard let encrypted = all.first(where: { $0.id == id }) else {
      throw EventCLIError.notFound("Reminder with ID '\(id)' not found")
    }

    let existing = try await encryptor.decryptReminders([encrypted])[0]
    let now = ISO8601DateFormatter.syncISO8601.string(from: Date())

    let updatedPlain = Reminder(
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

    let d1Reminders = try await encryptor.encryptReminders([updatedPlain])
    _ = try await client.push(entity: "reminders", items: d1Reminders, id: { $0.id })
    return updatedPlain
  }

  // MARK: - Delete

  public func deleteReminder(id: String) async throws {
    try await client.delete(
      entity: "reminders", id: id,
      lastModified: ISO8601DateFormatter.syncISO8601.string(from: Date()))
  }
}

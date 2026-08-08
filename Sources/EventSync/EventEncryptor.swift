import AppleSyncKit
import EventModels
import Foundation

// MARK: - Event Encryptor

/// Transparently end-to-end encrypts the sensitive fields of reminders and
/// calendar events at the D1 boundary, so the Cloudflare Worker only ever stores
/// ciphertext. Encryption happens on push and decryption on pull, so the local
/// store (EventKit on macOS, SQLite on Linux) always holds plaintext. Titles,
/// list/calendar names, and dates stay plaintext so entities remain listable
/// without the key.
///
/// The carrier format matches the direct-access `CloudflareReminderService` /
/// `CloudflareCalendarService` (same `EncryptedCarrier`, `EncryptedPayload`,
/// AES-GCM, and AAD `recordId|modifiedDate`), so data written by either path is
/// interchangeable.
public actor EventEncryptor {
  private let encryption: EncryptionService

  public init(encryption: EncryptionService) {
    self.encryption = encryption
  }

  /// Builds an encryptor from `EVENT_ENCRYPTION_KEY`, or throws a helpful error
  /// when the key is missing or malformed.
  public static func fromEnvironment() throws -> EventEncryptor {
    let key = try EncryptionService.keyFromEnvironment("EVENT_ENCRYPTION_KEY")
    return EventEncryptor(encryption: EncryptionService(key: key))
  }

  // MARK: - Reminders

  /// Returns copies of the reminders with their sensitive fields sealed into an
  /// encrypted carrier carried in `notes`. Reminders with nothing sensitive pass
  /// through untouched.
  public func encryptReminders(_ reminders: [Reminder]) async throws -> [Reminder] {
    var result: [Reminder] = []
    result.reserveCapacity(reminders.count)
    for reminder in reminders {
      result.append(try await encryptReminder(reminder))
    }
    return result
  }

  public func decryptReminders(_ reminders: [Reminder]) async throws -> [Reminder] {
    var result: [Reminder] = []
    result.reserveCapacity(reminders.count)
    for reminder in reminders {
      result.append(try await decryptReminder(reminder))
    }
    return result
  }

  /// Decrypts every non-deleted item's body in a pull response, leaving deleted
  /// tombstones and plaintext bodies untouched.
  public func decryptResponse(
    _ response: PullResponse<Reminder>
  ) async throws -> PullResponse<Reminder> {
    var items: [PullItem<Reminder>] = []
    items.reserveCapacity(response.items.count)
    for item in response.items {
      if item.deleted {
        items.append(item)
      } else {
        let decrypted = try await decryptReminder(item.data)
        items.append(
          PullItem(
            id: item.id, data: decrypted, deleted: item.deleted,
            updatedAt: item.updatedAt, lastModified: item.lastModified))
      }
    }
    return PullResponse(items: items, cursor: response.cursor, hasMore: response.hasMore)
  }

  private func encryptReminder(_ reminder: Reminder) async throws -> Reminder {
    let payload = EncryptedPayload(
      notes: reminder.notes,
      url: reminder.url,
      location: reminder.location,
      alarms: reminder.alarms,
      recurrenceRules: reminder.recurrenceRules
    )
    guard !payload.isEmpty else { return reminder }

    let aadDate = Self.aadDate(
      lastModified: reminder.lastModifiedDate, creation: reminder.creationDate)
    let encrypted = try await encryption.encrypt(
      payload, recordId: reminder.id, modifiedDate: aadDate)
    let carrier = EncryptedCarrier(p: encrypted.encryptedPayload, i: encrypted.encryptedIV)
    let carrierJSON = try carrier.toJSONString()

    return Reminder(
      id: reminder.id,
      title: reminder.title,
      isCompleted: reminder.isCompleted,
      isFlagged: reminder.isFlagged,
      list: reminder.list,
      notes: carrierJSON,
      url: nil,
      location: nil,
      timeZone: reminder.timeZone,
      dueDate: reminder.dueDate,
      startDate: reminder.startDate,
      completionDate: reminder.completionDate,
      creationDate: reminder.creationDate,
      lastModifiedDate: reminder.lastModifiedDate,
      externalId: reminder.externalId,
      priority: reminder.priority,
      alarms: nil,
      recurrenceRules: nil,
      locationTrigger: reminder.locationTrigger
    )
  }

  private func decryptReminder(_ reminder: Reminder) async throws -> Reminder {
    guard let notes = reminder.notes, let carrier = EncryptedCarrier.fromJSON(notes) else {
      return reminder
    }
    let aadDate = Self.aadDate(
      lastModified: reminder.lastModifiedDate, creation: reminder.creationDate)
    let payload: EncryptedPayload = try await encryption.decrypt(
      carrier.p, iv: carrier.i, recordId: reminder.id, modifiedDate: aadDate)

    return Reminder(
      id: reminder.id,
      title: reminder.title,
      isCompleted: reminder.isCompleted,
      isFlagged: reminder.isFlagged,
      list: reminder.list,
      notes: payload.notes,
      url: payload.url ?? reminder.url,
      location: payload.location ?? reminder.location,
      timeZone: reminder.timeZone,
      dueDate: reminder.dueDate,
      startDate: reminder.startDate,
      completionDate: reminder.completionDate,
      creationDate: reminder.creationDate,
      lastModifiedDate: reminder.lastModifiedDate,
      externalId: reminder.externalId,
      priority: reminder.priority,
      alarms: payload.alarms ?? reminder.alarms,
      recurrenceRules: payload.recurrenceRules ?? reminder.recurrenceRules,
      locationTrigger: reminder.locationTrigger
    )
  }

  // MARK: - Calendar Events

  public func encryptEvents(_ events: [CalendarEvent]) async throws -> [CalendarEvent] {
    var result: [CalendarEvent] = []
    result.reserveCapacity(events.count)
    for event in events {
      result.append(try await encryptEvent(event))
    }
    return result
  }

  public func decryptEvents(_ events: [CalendarEvent]) async throws -> [CalendarEvent] {
    var result: [CalendarEvent] = []
    result.reserveCapacity(events.count)
    for event in events {
      result.append(try await decryptEvent(event))
    }
    return result
  }

  public func decryptResponse(
    _ response: PullResponse<CalendarEvent>
  ) async throws -> PullResponse<CalendarEvent> {
    var items: [PullItem<CalendarEvent>] = []
    items.reserveCapacity(response.items.count)
    for item in response.items {
      if item.deleted {
        items.append(item)
      } else {
        let decrypted = try await decryptEvent(item.data)
        items.append(
          PullItem(
            id: item.id, data: decrypted, deleted: item.deleted,
            updatedAt: item.updatedAt, lastModified: item.lastModified))
      }
    }
    return PullResponse(items: items, cursor: response.cursor, hasMore: response.hasMore)
  }

  private func encryptEvent(_ event: CalendarEvent) async throws -> CalendarEvent {
    let attendeeStrings = event.attendees?.map { $0.url }
    let payload = EncryptedPayload(
      notes: event.notes,
      url: event.url,
      location: event.location,
      alarms: event.alarms,
      recurrenceRules: event.recurrenceRules,
      attendees: attendeeStrings
    )
    guard !payload.isEmpty else { return event }

    let aadDate = Self.aadDate(lastModified: event.lastModifiedDate, creation: event.creationDate)
    let encrypted = try await encryption.encrypt(
      payload, recordId: event.id, modifiedDate: aadDate)
    let carrier = EncryptedCarrier(p: encrypted.encryptedPayload, i: encrypted.encryptedIV)
    let carrierJSON = try carrier.toJSONString()

    return CalendarEvent(
      id: event.id,
      title: event.title,
      calendar: event.calendar,
      startDate: event.startDate,
      endDate: event.endDate,
      isAllDay: event.isAllDay,
      location: nil,
      notes: carrierJSON,
      url: nil,
      timeZone: event.timeZone,
      dateFormatVersion: event.dateFormatVersion,
      creationDate: event.creationDate,
      lastModifiedDate: event.lastModifiedDate,
      status: event.status,
      availability: event.availability,
      alarms: nil,
      recurrenceRules: nil,
      attendees: nil
    )
  }

  private func decryptEvent(_ event: CalendarEvent) async throws -> CalendarEvent {
    guard let notes = event.notes, let carrier = EncryptedCarrier.fromJSON(notes) else {
      return event
    }
    let aadDate = Self.aadDate(lastModified: event.lastModifiedDate, creation: event.creationDate)
    let payload: EncryptedPayload = try await encryption.decrypt(
      carrier.p, iv: carrier.i, recordId: event.id, modifiedDate: aadDate)

    let attendees: [Participant]? = payload.attendees.map { urls in
      urls.map {
        Participant(name: nil, url: $0, status: nil, role: nil, type: nil, isCurrentUser: nil)
      }
    }

    return CalendarEvent(
      id: event.id,
      title: event.title,
      calendar: event.calendar,
      startDate: event.startDate,
      endDate: event.endDate,
      isAllDay: event.isAllDay,
      location: payload.location ?? event.location,
      notes: payload.notes,
      url: payload.url ?? event.url,
      timeZone: event.timeZone,
      dateFormatVersion: event.dateFormatVersion,
      creationDate: event.creationDate,
      lastModifiedDate: event.lastModifiedDate,
      status: event.status,
      availability: event.availability,
      alarms: payload.alarms ?? event.alarms,
      recurrenceRules: payload.recurrenceRules ?? event.recurrenceRules,
      attendees: attendees ?? event.attendees
    )
  }

  // MARK: - Helpers

  private static func aadDate(lastModified: String?, creation: String?) -> String {
    lastModified ?? creation ?? ""
  }
}

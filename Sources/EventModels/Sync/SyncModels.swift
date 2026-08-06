import AppleSyncKit
import Foundation

// MARK: - Entity-keyed sync state

// These keep `event`'s on-disk JSON shape (keys `reminders` / `calendarEvents` /
// `reminderLists`). The generic pieces (SyncConfig, results, SyncEntityState,
// snapshot encoder, mapping inversion, timestamp/cursor helpers) live in
// AppleSyncKit.

public struct SyncIdMapping: Codable, Sendable {
  public var reminders: [String: String]
  public var calendarEvents: [String: String]
  public var reminderLists: [String: String]

  public init(
    reminders: [String: String] = [:],
    calendarEvents: [String: String] = [:],
    reminderLists: [String: String] = [:]
  ) {
    self.reminders = reminders
    self.calendarEvents = calendarEvents
    self.reminderLists = reminderLists
  }
}

public struct SyncCursors: Codable, Sendable {
  public var reminders: String?
  public var calendarEvents: String?
  public var reminderLists: String?

  public init(
    reminders: String? = nil, calendarEvents: String? = nil, reminderLists: String? = nil
  ) {
    self.reminders = reminders
    self.calendarEvents = calendarEvents
    self.reminderLists = reminderLists
  }
}

public struct SyncState: Codable, Sendable {
  public var reminders: SyncEntityState
  public var calendarEvents: SyncEntityState
  public var reminderLists: SyncEntityState

  public init(
    reminders: SyncEntityState = SyncEntityState(),
    calendarEvents: SyncEntityState = SyncEntityState(),
    reminderLists: SyncEntityState = SyncEntityState()
  ) {
    self.reminders = reminders
    self.calendarEvents = calendarEvents
    self.reminderLists = reminderLists
  }
}

// MARK: - Snapshot volatile keys

/// Fields excluded from the content snapshot used for change detection: identity
/// fields, EventKit-managed timestamps that change on any local write, computed
/// fields EventKit derives from device state, and read-only fields the CLI cannot
/// modify. Passed to the shared engine.
public let eventSnapshotVolatileKeys: Set<String> = [
  "id", "lastModifiedDate", "creationDate", "completionDate",
  "timeZone", "status", "availability",
  "alarms", "recurrenceRules", "attendees",
  "externalId", "isFlagged", "locationTrigger",
]

/// Calendar events sync their timezone identifier as user-editable content.
/// Other entities retain the generic set because they do not expose this field.
public let calendarEventSnapshotVolatileKeys: Set<String> =
  eventSnapshotVolatileKeys.subtracting(["timeZone"])

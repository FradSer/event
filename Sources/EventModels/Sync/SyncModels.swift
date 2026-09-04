import AppleSyncKit
import Foundation

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

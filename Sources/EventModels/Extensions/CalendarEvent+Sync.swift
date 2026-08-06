import AppleSyncKit
import Foundation

extension CalendarEvent {
  /// Whether timed dates were serialized in the stored event timezone.
  public var usesEventTimeZoneDateFormat: Bool {
    !isAllDay && dateFormatVersion == Self.currentDateFormatVersion
  }

  /// The timezone identifier that can safely be passed to an EventKit parser.
  /// Legacy records do not carry enough information to recover their source
  /// machine timezone, so they retain the pre-versioned local-time behavior.
  public var syncTimeZoneIdentifier: String? {
    guard usesEventTimeZoneDateFormat else { return nil }
    return timeZone
  }

  /// Whether a synced floating event should clear an existing EventKit timezone.
  public var shouldClearTimeZoneOnSync: Bool {
    usesEventTimeZoneDateFormat && timeZone == nil
  }

  /// Returns a canonical UTC range for sync comparisons.
  ///
  /// Calendar event date strings are formatted in the event's timezone, so raw
  /// string comparisons can put an event on the wrong side of a sync boundary.
  /// Invalid legacy values retain their original representation instead of
  /// making sync state impossible to read.
  public func syncDateRange() -> SyncDateRange {
    let fallback = SyncDateRange(start: startDate, end: endDate)
    let eventTimeZone = TimeZone(identifier: timeZone ?? "") ?? .current
    let parsingTimeZone = usesEventTimeZoneDateFormat ? eventTimeZone : .current

    guard let start = Self.parseSyncDate(startDate, timeZone: parsingTimeZone),
      let end = Self.parseSyncDate(endDate, timeZone: parsingTimeZone)
    else {
      return fallback
    }

    return Self.canonicalRange(start: start, end: end)
  }

  /// Builds a canonical range from a command's local date boundaries.
  public static func syncDateRange(start: String, end: String) -> SyncDateRange {
    let fallback = SyncDateRange(start: start, end: end)
    guard let parsedStart = parseSyncDate(start, timeZone: .current),
      let parsedEnd = parseSyncDate(end, timeZone: .current)
    else {
      return fallback
    }

    return canonicalRange(start: parsedStart, end: parsedEnd)
  }

  private static func parseSyncDate(_ string: String, timeZone: TimeZone) -> Date? {
    if Date.isAllDayFormat(string) {
      return try? DateValidator.validateDate(string)
    }
    if let date = try? DateValidator.validateDateTime(string, timeZone: timeZone) {
      return date
    }

    return ISO8601DateFormatter.syncISO8601.date(from: string)
      ?? ISO8601DateFormatter().date(from: string)
  }

  private static func canonicalRange(start: Date, end: Date) -> SyncDateRange {
    SyncDateRange(
      start: ISO8601DateFormatter.syncISO8601.string(from: start),
      end: ISO8601DateFormatter.syncISO8601.string(from: end)
    )
  }
}

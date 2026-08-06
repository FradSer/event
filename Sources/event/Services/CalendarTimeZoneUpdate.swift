import Foundation

enum CalendarTimeZoneUpdate {
  static func parsingTimeZone(
    clearTimeZone: Bool,
    requested: TimeZone?,
    existing: TimeZone?
  ) -> TimeZone {
    if clearTimeZone {
      return .current
    }
    return requested ?? existing ?? .current
  }

  static func resolvedTimeZone(
    isAllDay: Bool,
    clearTimeZone: Bool,
    requested: TimeZone?,
    existing: TimeZone?
  ) -> TimeZone? {
    guard !isAllDay, !clearTimeZone else {
      return nil
    }
    return requested ?? existing
  }
}

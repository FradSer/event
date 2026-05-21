import Foundation

// MARK: - Sync Timestamp Parsing

/// Parses sync timestamp strings into `Date` for last-write-wins comparison.
/// Tolerates ISO 8601 with or without fractional seconds, plus the bare
/// `yyyy-MM-dd HH:mm:ss` form, so values from EventKit and the D1 backend
/// can be compared regardless of which side produced them.
public enum SyncTimestamp {
  private static let iso8601: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  private static let bare: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    return formatter
  }()

  /// Returns the parsed date, or `nil` when the string is empty or unrecognized.
  public static func parse(_ string: String?) -> Date? {
    guard let string, !string.isEmpty else { return nil }
    return ISO8601DateFormatter.eventISO8601.date(from: string)
      ?? iso8601.date(from: string)
      ?? bare.date(from: string)
  }
}

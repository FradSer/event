import AppleSyncKit
import Foundation

/// Centralized date validation that rejects auto-corrected invalid dates
public enum DateValidator {
  private static func parseStrictISO8601(_ string: String) -> Date? {
    let pattern = #"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?(?:Z|[+-][0-9]{2}:[0-9]{2})$"#
    guard string.range(of: pattern, options: .regularExpression) != nil,
      let hour = Int(string.dropFirst(11).prefix(2)),
      let minute = Int(string.dropFirst(14).prefix(2)),
      let second = Int(string.dropFirst(17).prefix(2)), hour < 24, minute < 60,
      second < 60,
      (try? validateDate(String(string.prefix(10)))) != nil
    else {
      return nil
    }

    if !string.hasSuffix("Z") {
      let offset = string.suffix(6)
      guard let offsetHour = Int(offset.prefix(3).dropFirst()),
        let offsetMinute = Int(offset.suffix(2)), offsetHour < 24, offsetMinute < 60
      else {
        return nil
      }
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = string.contains(".")
      ? [.withInternetDateTime, .withFractionalSeconds]
      : [.withInternetDateTime]
    return formatter.date(from: string)
  }

  /// Validates datetime string in format "yyyy-MM-dd HH:mm:ss"
  /// Rejects auto-corrected dates (e.g., Feb 30 -> Mar 2)
  public static func validateDateTime(
    _ string: String,
    timeZone: TimeZone = .current
  ) throws -> Date {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.timeZone = timeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)

    guard let date = formatter.date(from: string) else {
      throw EventCLIError.invalidDate(
        "Invalid datetime format. Expected yyyy-MM-dd HH:mm:ss, got: \(string)"
      )
    }

    let reformatted = formatter.string(from: date)
    guard reformatted == string else {
      throw EventCLIError.invalidDate(
        "Invalid date (auto-corrected from \(string) to \(reformatted)). "
          + "Please provide a valid date."
      )
    }

    try validateReasonableDate(date, timeZone: timeZone)
    return date
  }

  /// Reformats a timed date string in another time zone without changing its instant.
  public static func convertDateTime(
    _ string: String,
    from sourceTimeZone: TimeZone,
    to destinationTimeZone: TimeZone
  ) throws -> String {
    let date: Date
    do {
      date = try validateDateTime(string, timeZone: sourceTimeZone)
    } catch {
      guard let isoDate = ISO8601DateFormatter().date(from: string) else {
        throw error
      }
      try validateReasonableDate(isoDate, timeZone: sourceTimeZone)
      date = isoDate
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.timeZone = destinationTimeZone
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: date)
  }

  /// Validates date-only string in format "yyyy-MM-dd"
  /// Used for all-day events
  public static func validateDate(_ string: String) throws -> Date {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)

    guard let date = formatter.date(from: string) else {
      throw EventCLIError.invalidDate("Invalid date format. Expected yyyy-MM-dd, got: \(string)")
    }

    let reformatted = formatter.string(from: date)
    guard reformatted == string else {
      throw EventCLIError.invalidDate(
        "Invalid date (auto-corrected from \(string) to \(reformatted)). "
          + "Please provide a valid date."
      )
    }

    try validateReasonableDate(date, timeZone: .current)
    return date
  }

  /// Checks if date components represent a valid date (not auto-corrected)
  public static func isValidDate(year: Int, month: Int, day: Int) -> Bool {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.timeZone = TimeZone.current

    guard let date = Calendar.current.date(from: components) else {
      return false
    }

    let resultComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return resultComponents.year == year && resultComponents.month == month
      && resultComponents.day == day
  }

  /// Validates that end date is after start date
  public static func validateDateRange(start: Date, end: Date) throws {
    guard end >= start else {
      throw EventCLIError.invalidDateRange(
        "End date must be after or equal to start date. Start: \(start), End: \(end)"
      )
    }
  }

  /// Validates that date is within the reasonable range (1900-2100) in the given time zone
  public static func validateReasonableDate(
    _ date: Date,
    timeZone: TimeZone = .current
  ) throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let components = calendar.dateComponents([.year], from: date)

    guard let year = components.year else {
      throw EventCLIError.dateOutOfRange("Unable to extract year from date")
    }

    guard year >= 1900, year <= 2100 else {
      throw EventCLIError.dateOutOfRange("Date year must be between 1900 and 2100, got: \(year)")
    }
  }

  public static func validatedDateWindow(
    startDate: String?,
    endDate: String?
  ) throws -> (start: Date, end: Date)? {
    guard let startDate, let endDate else {
      guard startDate == nil, endDate == nil else {
        throw EventCLIError.invalidInput(
          "Use both start and end dates to filter reminders by due date."
        )
      }
      return nil
    }

    let start = try validateDate(startDate)
    let end = try validateDate(endDate)
    try validateDateRange(start: start, end: end)
    return (start, end)
  }

  ///
  /// `dateString` may be `yyyy-MM-dd`, `yyyy-MM-dd HH:mm:ss`, or an ISO 8601
  /// value (e.g. `yyyy-MM-dd'T'HH:mm:ssZ`) — the shapes `Reminder.dueDate` can
  /// take across backends. Unparseable strings (or a value with no due date)
  /// are treated as outside the window so a windowed query never returns a
  /// reminder it can't bound.
  public static func isWithinDateWindow(
    _ dateString: String?,
    startDate: String,
    endDate: String
  ) -> Bool {
    guard let dateString, !dateString.isEmpty,
      let date = (try? validateDate(dateString))
        ?? (try? validateDateTime(dateString))
        ?? (try? validateDateTime(dateString.replacingOccurrences(of: "T", with: " ")))
        ?? parseStrictISO8601(dateString)
    else {
      return false
    }

    guard let start = try? validateDate(startDate),
      let end = try? validateDate(endDate)
    else {
      return false
    }

    return date >= start && date < end
  }

  /// Returns whether a due-date string falls inside a half-open window whose
  /// bounds have already been parsed to `Date`. Callers that validate the
  /// bounds once (e.g. a CLI entry point) should pass the parsed dates here so
  /// a windowed scan over a large store does not re-parse the same two bounds
  /// for every item.
  public static func isWithinDateWindow(
    _ dateString: String?,
    start: Date,
    end: Date
  ) -> Bool {
    guard let dateString, !dateString.isEmpty,
      let date = (try? validateDate(dateString))
        ?? (try? validateDateTime(dateString))
        ?? (try? validateDateTime(dateString.replacingOccurrences(of: "T", with: " ")))
        ?? parseStrictISO8601(dateString)
    else {
      return false
    }

    return date >= start && date < end
  }
}

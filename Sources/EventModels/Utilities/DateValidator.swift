import AppleSyncKit
import Foundation

/// Centralized date validation that rejects auto-corrected invalid dates
public enum DateValidator {
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
    var calendar = Calendar.current
    calendar.timeZone = timeZone
    let components = calendar.dateComponents([.year], from: date)

    guard let year = components.year else {
      throw EventCLIError.dateOutOfRange("Unable to extract year from date")
    }

    guard year >= 1900, year <= 2100 else {
      throw EventCLIError.dateOutOfRange("Date year must be between 1900 and 2100, got: \(year)")
    }
  }

  /// Returns whether a due-date string falls inside the half-open window
  /// `[startDate, endDate)`. Both bounds are date-only (`yyyy-MM-dd`); the
  /// start day is inclusive and the end day exclusive, matching `calendar list`.
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
        ?? ISO8601DateFormatter.syncISO8601.date(from: dateString)
        ?? ISO8601DateFormatter().date(from: dateString)
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
}

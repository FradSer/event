import Foundation

/// Centralized date validation that rejects auto-corrected invalid dates
public enum DateValidator {
  /// Validates datetime string in format "yyyy-MM-dd HH:mm:ss"
  /// Rejects auto-corrected dates (e.g., Feb 30 -> Mar 2)
  public static func validateDateTime(_ string: String) throws -> Date {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.timeZone = TimeZone.current
    formatter.locale = Locale(identifier: "en_US_POSIX")

    guard let date = formatter.date(from: string) else {
      throw EventCLIError.invalidDate(
        "Invalid datetime format. Expected yyyy-MM-dd HH:mm:ss, got: \(string)"
      )
    }

    let reformatted = formatter.string(from: date)
    guard reformatted == string else {
      throw EventCLIError.invalidDate(
        "Invalid date (auto-corrected from \(string) to \(reformatted)). Please provide a valid date."
      )
    }

    try validateReasonableDate(date)
    return date
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
        "Invalid date (auto-corrected from \(string) to \(reformatted)). Please provide a valid date."
      )
    }

    try validateReasonableDate(date)
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

  /// Validates that date is within reasonable range (1900-2100)
  public static func validateReasonableDate(_ date: Date) throws {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year], from: date)

    guard let year = components.year else {
      throw EventCLIError.dateOutOfRange("Unable to extract year from date")
    }

    guard year >= 1900, year <= 2100 else {
      throw EventCLIError.dateOutOfRange("Date year must be between 1900 and 2100, got: \(year)")
    }
  }
}

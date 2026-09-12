import Foundation

// MARK: - Recurrence Rule Model

public struct RecurrenceRule: Codable, Sendable, Equatable {
  public let frequency: String
  public let interval: Int
  public let daysOfWeek: [String]?
  public let daysOfMonth: [Int]?
  public let monthsOfYear: [Int]?
  public let weeksOfYear: [Int]?
  public let daysOfYear: [Int]?
  public let setPositions: [Int]?
  public let endDate: String?
  /// Number of occurrences after which the series ends; exclusive with `endDate`.
  public let occurrenceCount: Int?

  /// Weekday names as used in `daysOfWeek`, indexed like `EKWeekday` (1 = Sunday).
  public static let weekdayNames = [
    "", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
  ]

  public init(
    frequency: String,
    interval: Int,
    daysOfWeek: [String]?,
    daysOfMonth: [Int]?,
    monthsOfYear: [Int]?,
    weeksOfYear: [Int]?,
    daysOfYear: [Int]?,
    setPositions: [Int]?,
    endDate: String?,
    occurrenceCount: Int? = nil
  ) {
    self.frequency = frequency
    self.interval = interval
    self.daysOfWeek = daysOfWeek
    self.daysOfMonth = daysOfMonth
    self.monthsOfYear = monthsOfYear
    self.weeksOfYear = weeksOfYear
    self.daysOfYear = daysOfYear
    self.setPositions = setPositions
    self.endDate = endDate
    self.occurrenceCount = occurrenceCount
  }
}

import EventModels
import Foundation

struct CalendarDateInputResolution {
  let start: Date
  let end: Date
  let isAllDay: Bool
}

enum CalendarDateInputResolver {
  static func resolve(
    currentIsAllDay: Bool,
    currentStart: Date,
    currentEnd: Date,
    startInput: String?,
    endInput: String?
  ) throws -> CalendarDateInputResolution {
    let startIsAllDay = startInput.map(Date.isAllDayFormat)
    let endIsAllDay = endInput.map(Date.isAllDayFormat)

    if let startIsAllDay, let endIsAllDay, startIsAllDay != endIsAllDay {
      throw EventCLIError.invalidInput(
        "Start and end dates must both use date-only or date-time format."
      )
    }

    let isAllDay = startIsAllDay ?? endIsAllDay ?? currentIsAllDay
    let start = try resolveDate(input: startInput, fallback: currentStart, isAllDay: isAllDay)
    let end = try resolveDate(input: endInput, fallback: currentEnd, isAllDay: isAllDay)

    try DateValidator.validateDateRange(start: start, end: end)
    return CalendarDateInputResolution(start: start, end: end, isAllDay: isAllDay)
  }

  private static func resolveDate(
    input: String?,
    fallback: Date,
    isAllDay: Bool
  ) throws -> Date {
    guard let input else {
      return fallback
    }
    if isAllDay {
      return try Date.validated(dateString: input)
    }
    return try Date.validated(dateTimeString: input)
  }
}

import EventKit
import EventModels
import Foundation

extension RecurrenceRule {
  init(from ekRule: EKRecurrenceRule) {
    let frequency: String
    switch ekRule.frequency {
    case .daily: frequency = "daily"
    case .weekly: frequency = "weekly"
    case .monthly: frequency = "monthly"
    case .yearly: frequency = "yearly"
    @unknown default: frequency = "unknown"
    }

    let weekdaySymbols = [
      "", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
    ]
    let daysOfWeek = ekRule.daysOfTheWeek?.compactMap { dayOfWeek -> String? in
      let index = dayOfWeek.dayOfTheWeek.rawValue
      guard index >= 0, index < weekdaySymbols.count else { return nil }
      return weekdaySymbols[index]
    }

    let endDate: String?
    if let endDateValue = ekRule.recurrenceEnd?.endDate {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd"
      endDate = formatter.string(from: endDateValue)
    } else {
      endDate = nil
    }

    self.init(
      frequency: frequency,
      interval: ekRule.interval,
      daysOfWeek: daysOfWeek,
      daysOfMonth: ekRule.daysOfTheMonth?.map { $0.intValue },
      monthsOfYear: ekRule.monthsOfTheYear?.map { $0.intValue },
      weeksOfYear: ekRule.weeksOfTheYear?.map { $0.intValue },
      daysOfYear: ekRule.daysOfTheYear?.map { $0.intValue },
      setPositions: ekRule.setPositions?.map { $0.intValue },
      endDate: endDate
    )
  }
}

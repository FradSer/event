import EventKit
import Foundation

// MARK: - Recurrence Rule Model

struct RecurrenceRule: Codable {
    let frequency: String
    let interval: Int
    let daysOfWeek: [String]?
    let daysOfMonth: [Int]?
    let monthsOfYear: [Int]?
    let weeksOfYear: [Int]?
    let daysOfYear: [Int]?
    let setPositions: [Int]?
    let endDate: String?

    init(from ekRule: EKRecurrenceRule) {
        // Frequency
        switch ekRule.frequency {
        case .daily:
            frequency = "daily"
        case .weekly:
            frequency = "weekly"
        case .monthly:
            frequency = "monthly"
        case .yearly:
            frequency = "yearly"
        @unknown default:
            frequency = "unknown"
        }

        interval = ekRule.interval

        // Days of week
        daysOfWeek = ekRule.daysOfTheWeek?.map { dayOfWeek in
            let weekdaySymbols = [
                "", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
            ]
            return weekdaySymbols[dayOfWeek.dayOfTheWeek.rawValue]
        }

        // Days of month
        daysOfMonth = ekRule.daysOfTheMonth?.map { $0.intValue }

        // Months of year
        monthsOfYear = ekRule.monthsOfTheYear?.map { $0.intValue }

        // Weeks of year
        weeksOfYear = ekRule.weeksOfTheYear?.map { $0.intValue }

        // Days of year
        daysOfYear = ekRule.daysOfTheYear?.map { $0.intValue }

        // Set positions
        setPositions = ekRule.setPositions?.map { $0.intValue }

        // End date
        if let endDate = ekRule.recurrenceEnd?.endDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            self.endDate = formatter.string(from: endDate)
        } else {
            endDate = nil
        }
    }
}

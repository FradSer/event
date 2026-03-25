import Foundation

// MARK: - Recurrence Rule Model

public struct RecurrenceRule: Codable, Sendable {
    public let frequency: String
    public let interval: Int
    public let daysOfWeek: [String]?
    public let daysOfMonth: [Int]?
    public let monthsOfYear: [Int]?
    public let weeksOfYear: [Int]?
    public let daysOfYear: [Int]?
    public let setPositions: [Int]?
    public let endDate: String?

    public init(
        frequency: String,
        interval: Int,
        daysOfWeek: [String]?,
        daysOfMonth: [Int]?,
        monthsOfYear: [Int]?,
        weeksOfYear: [Int]?,
        daysOfYear: [Int]?,
        setPositions: [Int]?,
        endDate: String?
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
    }
}

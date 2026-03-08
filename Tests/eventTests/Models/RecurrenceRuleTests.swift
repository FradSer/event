import XCTest
import EventKit
@testable import event

final class RecurrenceRuleTests: XCTestCase {

    func testRecurrenceRuleDaily() {
        let ekRule = EKRecurrenceRule(
            recurrenceWith: .daily,
            interval: 1,
            end: nil
        )

        let rule = RecurrenceRule(from: ekRule)

        XCTAssertEqual(rule.frequency, "daily")
        XCTAssertEqual(rule.interval, 1)
        XCTAssertNil(rule.endDate)
    }

    func testRecurrenceRuleWeekly() {
        let monday = EKRecurrenceDayOfWeek(.monday)
        let friday = EKRecurrenceDayOfWeek(.friday)

        let ekRule = EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            daysOfTheWeek: [monday, friday],
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: nil
        )

        let rule = RecurrenceRule(from: ekRule)

        XCTAssertEqual(rule.frequency, "weekly")
        XCTAssertEqual(rule.interval, 1)
        XCTAssertEqual(rule.daysOfWeek, ["Monday", "Friday"])
    }

    func testRecurrenceRuleMonthly() {
        let ekRule = EKRecurrenceRule(
            recurrenceWith: .monthly,
            interval: 2,
            daysOfTheWeek: nil,
            daysOfTheMonth: [15],
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: nil
        )

        let rule = RecurrenceRule(from: ekRule)

        XCTAssertEqual(rule.frequency, "monthly")
        XCTAssertEqual(rule.interval, 2)
        XCTAssertEqual(rule.daysOfMonth, [15])
    }

    func testRecurrenceRuleYearly() {
        let ekRule = EKRecurrenceRule(
            recurrenceWith: .yearly,
            interval: 1,
            daysOfTheWeek: nil,
            daysOfTheMonth: nil,
            monthsOfTheYear: [6, 12],
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: nil
        )

        let rule = RecurrenceRule(from: ekRule)

        XCTAssertEqual(rule.frequency, "yearly")
        XCTAssertEqual(rule.interval, 1)
        XCTAssertEqual(rule.monthsOfYear, [6, 12])
    }

    func testRecurrenceRuleWithEndDate() {
        let endDate = Date(timeIntervalSince1970: 1735689600) // 2025-01-01
        let recurrenceEnd = EKRecurrenceEnd(end: endDate)

        let ekRule = EKRecurrenceRule(
            recurrenceWith: .daily,
            interval: 1,
            end: recurrenceEnd
        )

        let rule = RecurrenceRule(from: ekRule)

        XCTAssertNotNil(rule.endDate)
        XCTAssertTrue(rule.endDate?.starts(with: "202") ?? false)
    }

    func testRecurrenceRuleCodable() throws {
        let ekRule = EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 2,
            end: nil
        )

        let rule = RecurrenceRule(from: ekRule)

        let encoder = JSONEncoder()
        let data = try encoder.encode(rule)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RecurrenceRule.self, from: data)

        XCTAssertEqual(decoded.frequency, rule.frequency)
        XCTAssertEqual(decoded.interval, rule.interval)
    }
}

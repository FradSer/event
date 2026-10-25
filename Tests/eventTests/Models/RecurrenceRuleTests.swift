#if canImport(EventKit)
  import EventKit
  import EventModels
  import XCTest

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
      let endDate = Date(timeIntervalSince1970: 1_735_689_600)  // 2025-01-01
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

    func testRecurrenceRuleWithOccurrenceCount() {
      let ekRule = EKRecurrenceRule(
        recurrenceWith: .weekly,
        interval: 1,
        end: EKRecurrenceEnd(occurrenceCount: 5)
      )

      let rule = RecurrenceRule(from: ekRule)

      XCTAssertEqual(rule.occurrenceCount, 5)
      XCTAssertNil(rule.endDate)
    }

    // MARK: - toEKRecurrenceRule

    func testToEKRecurrenceRuleWeeklyRoundTrip() throws {
      let rule = RecurrenceRule(
        frequency: "weekly",
        interval: 2,
        daysOfWeek: ["Monday", "Wednesday"],
        daysOfMonth: nil,
        monthsOfYear: nil,
        weeksOfYear: nil,
        daysOfYear: nil,
        setPositions: nil,
        endDate: "2027-12-31"
      )

      let ekRule = try rule.toEKRecurrenceRule()

      XCTAssertEqual(ekRule.frequency, .weekly)
      XCTAssertEqual(ekRule.interval, 2)
      XCTAssertEqual(ekRule.daysOfTheWeek?.map { $0.dayOfTheWeek }, [.monday, .wednesday])
      XCTAssertNotNil(ekRule.recurrenceEnd?.endDate)

      let back = RecurrenceRule(from: ekRule)
      XCTAssertEqual(back.frequency, "weekly")
      XCTAssertEqual(back.interval, 2)
      XCTAssertEqual(back.daysOfWeek, ["Monday", "Wednesday"])
      XCTAssertEqual(back.endDate, "2027-12-31")
    }

    func testToEKRecurrenceRuleMonthlyWithCount() throws {
      let rule = RecurrenceRule(
        frequency: "monthly",
        interval: 1,
        daysOfWeek: nil,
        daysOfMonth: [1, 15],
        monthsOfYear: nil,
        weeksOfYear: nil,
        daysOfYear: nil,
        setPositions: nil,
        endDate: nil,
        occurrenceCount: 3
      )

      let ekRule = try rule.toEKRecurrenceRule()

      XCTAssertEqual(ekRule.frequency, .monthly)
      XCTAssertEqual(ekRule.daysOfTheMonth?.map { $0.intValue }, [1, 15])
      XCTAssertNil(ekRule.daysOfTheWeek)
      XCTAssertEqual(ekRule.recurrenceEnd?.occurrenceCount, 3)
      XCTAssertEqual(RecurrenceRule(from: ekRule).occurrenceCount, 3)
    }

    func testToEKRecurrenceRuleRejectsUnknownFrequencyAndWeekday() {
      let unknownFrequency = RecurrenceRule(
        frequency: "hourly", interval: 1, daysOfWeek: nil, daysOfMonth: nil, monthsOfYear: nil,
        weeksOfYear: nil, daysOfYear: nil, setPositions: nil, endDate: nil)
      XCTAssertThrowsError(try unknownFrequency.toEKRecurrenceRule())

      let unknownWeekday = RecurrenceRule(
        frequency: "weekly", interval: 1, daysOfWeek: ["Funday"], daysOfMonth: nil,
        monthsOfYear: nil, weeksOfYear: nil, daysOfYear: nil, setPositions: nil, endDate: nil)
      XCTAssertThrowsError(try unknownWeekday.toEKRecurrenceRule())
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
#endif

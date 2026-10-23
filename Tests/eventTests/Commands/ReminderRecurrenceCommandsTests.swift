import EventModels
import XCTest

@testable import event

/// Parsing and validation of `--recurrence*` / `--clear-recurrence` on
/// `reminders create` / `update`. Applying a rule needs a saved reminder and
/// permission, so that is checked against the built binary, not here.
final class ReminderRecurrenceCommandsTests: XCTestCase {

  private static let createBase = ["--title", "Test", "--due", "2027-01-01 09:00:00"]

  // MARK: - create parsing

  func testCreateWithoutRecurrenceFlagsResolvesToNil() throws {
    let cmd = try ReminderCommands.Create.parse(Self.createBase)
    XCTAssertFalse(cmd.recurrenceOptions.isPresent)
    XCTAssertNil(try cmd.recurrenceOptions.resolveRule())
  }

  func testCreateParsesMonthlyRule() throws {
    let cmd = try ReminderCommands.Create.parse(Self.createBase + ["--recurrence", "monthly"])
    let rule = try XCTUnwrap(try cmd.recurrenceOptions.resolveRule())
    XCTAssertEqual(rule.frequency, "monthly")
    XCTAssertEqual(rule.interval, 1)
    XCTAssertNil(rule.daysOfWeek)
    XCTAssertNil(rule.endDate)
    XCTAssertNil(rule.occurrenceCount)
  }

  func testCreateParsesFullWeeklyRule() throws {
    let cmd = try ReminderCommands.Create.parse(
      Self.createBase + [
        "--recurrence", "Weekly", "--recurrence-interval", "2",
        "--recurrence-days", "mon, Wed,7", "--recurrence-end", "2027-12-31",
      ])
    let rule = try XCTUnwrap(try cmd.recurrenceOptions.resolveRule())
    XCTAssertEqual(rule.frequency, "weekly")
    XCTAssertEqual(rule.interval, 2)
    XCTAssertEqual(rule.daysOfWeek, ["Monday", "Wednesday", "Saturday"])
    XCTAssertEqual(rule.endDate, "2027-12-31")
  }

  func testCreateParsesCountAndMonthlyDays() throws {
    let cmd = try ReminderCommands.Create.parse(
      Self.createBase + [
        "--recurrence", "monthly", "--recurrence-days-of-month", "1,15", "--recurrence-count", "6",
      ])
    let rule = try XCTUnwrap(try cmd.recurrenceOptions.resolveRule())
    XCTAssertEqual(rule.daysOfMonth, [1, 15])
    XCTAssertEqual(rule.occurrenceCount, 6)
  }

  func testCreateParsesYearlyMonths() throws {
    let cmd = try ReminderCommands.Create.parse(
      Self.createBase + ["--recurrence", "yearly", "--recurrence-months", "1,6,12"])
    let rule = try XCTUnwrap(try cmd.recurrenceOptions.resolveRule())
    XCTAssertEqual(rule.monthsOfYear, [1, 6, 12])
  }

  // MARK: - update parsing

  func testUpdateParsesRecurrenceAndClearFlag() throws {
    let cmd = try ReminderCommands.Update.parse(["--id", "R1", "--recurrence", "daily"])
    XCTAssertEqual(try cmd.recurrenceOptions.resolveRule()?.frequency, "daily")
    XCTAssertFalse(cmd.clearRecurrence)

    let clear = try ReminderCommands.Update.parse(["--id", "R1", "--clear-recurrence"])
    XCTAssertTrue(clear.clearRecurrence)
    XCTAssertFalse(clear.recurrenceOptions.isPresent)
  }

  // MARK: - resolveRule validation

  private func resolve(_ flags: [String]) throws -> RecurrenceRule? {
    try ReminderCommands.Create.parse(Self.createBase + flags).recurrenceOptions.resolveRule()
  }

  func testRefinementWithoutFrequencyIsRejected() {
    XCTAssertThrowsError(try resolve(["--recurrence-interval", "2"]))
    XCTAssertThrowsError(try resolve(["--recurrence-days", "mon"]))
  }

  func testUnknownFrequencyIsRejected() {
    XCTAssertThrowsError(try resolve(["--recurrence", "fortnightly"]))
    XCTAssertThrowsError(try resolve(["--recurrence", "hourly"]))
  }

  func testIntervalAndCountMustBePositive() {
    XCTAssertThrowsError(try resolve(["--recurrence", "daily", "--recurrence-interval", "0"]))
    XCTAssertThrowsError(try resolve(["--recurrence", "daily", "--recurrence-count", "0"]))
  }

  func testEndAndCountAreMutuallyExclusive() {
    XCTAssertThrowsError(
      try resolve([
        "--recurrence", "daily", "--recurrence-end", "2027-12-31", "--recurrence-count", "3",
      ]))
  }

  func testEndDateMustBeARealDay() {
    XCTAssertThrowsError(try resolve(["--recurrence", "daily", "--recurrence-end", "2027-02-30"]))
    XCTAssertThrowsError(
      try resolve(["--recurrence", "daily", "--recurrence-end", "2027-12-31 09:00:00"]))
  }

  func testWeekdayInputIsValidated() {
    XCTAssertThrowsError(try resolve(["--recurrence", "weekly", "--recurrence-days", "funday"]))
    XCTAssertThrowsError(try resolve(["--recurrence", "weekly", "--recurrence-days", "0"]))
    XCTAssertThrowsError(try resolve(["--recurrence", "weekly", "--recurrence-days", "8"]))
    XCTAssertThrowsError(try resolve(["--recurrence", "weekly", "--recurrence-days", ""]))
  }

  func testRefinementsAreTiedToFrequencies() {
    XCTAssertThrowsError(try resolve(["--recurrence", "daily", "--recurrence-days", "mon"]))
    XCTAssertNoThrow(try resolve(["--recurrence", "monthly", "--recurrence-days", "mon"]))
    XCTAssertNoThrow(try resolve(["--recurrence", "yearly", "--recurrence-days", "mon"]))
    XCTAssertThrowsError(
      try resolve(["--recurrence", "weekly", "--recurrence-days-of-month", "1"]))
    XCTAssertThrowsError(try resolve(["--recurrence", "monthly", "--recurrence-months", "1"]))
  }

  func testIntegerListsAreRangeChecked() {
    XCTAssertThrowsError(
      try resolve(["--recurrence", "monthly", "--recurrence-days-of-month", "0"]))
    XCTAssertThrowsError(
      try resolve(["--recurrence", "monthly", "--recurrence-days-of-month", "32"]))
    XCTAssertThrowsError(try resolve(["--recurrence", "yearly", "--recurrence-months", "13"]))
    XCTAssertThrowsError(try resolve(["--recurrence", "yearly", "--recurrence-months", "x"]))
  }
}

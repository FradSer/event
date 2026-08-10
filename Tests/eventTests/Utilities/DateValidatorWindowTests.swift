import EventModels
import XCTest

// MARK: - DateValidator Window Tests

final class DateValidatorWindowTests: XCTestCase {
  func testDateWithinWindowIsInclusive() {
    let result = DateValidator.isWithinDateWindow(
      "2026-08-10", startDate: "2026-08-10", endDate: "2026-08-24")
    XCTAssertTrue(result)
  }

  func testEndDateIsExclusive() {
    XCTAssertFalse(
      DateValidator.isWithinDateWindow(
        "2026-08-24", startDate: "2026-08-10", endDate: "2026-08-24"))
    XCTAssertFalse(
      DateValidator.isWithinDateWindow(
        "2026-08-24 09:00:00", startDate: "2026-08-10", endDate: "2026-08-24"))
  }

  func testDateTimeShapeIsComparedWithinTheWindow() {
    XCTAssertTrue(
      DateValidator.isWithinDateWindow(
        "2026-08-15 23:59:59", startDate: "2026-08-10", endDate: "2026-08-24"))
  }

  func testOutOfWindowDatesAreExcluded() {
    XCTAssertFalse(
      DateValidator.isWithinDateWindow(
        "2026-08-09 23:59:59", startDate: "2026-08-10", endDate: "2026-08-24"))
    XCTAssertFalse(
      DateValidator.isWithinDateWindow(
        "2026-08-25", startDate: "2026-08-10", endDate: "2026-08-24"))
  }

  func testNilOrEmptyDateIsOutsideWindow() {
    XCTAssertFalse(
      DateValidator.isWithinDateWindow(nil, startDate: "2026-08-10", endDate: "2026-08-24"))
    XCTAssertFalse(
      DateValidator.isWithinDateWindow("", startDate: "2026-08-10", endDate: "2026-08-24"))
  }

  func testInvalidBoundsReturnFalse() {
    XCTAssertFalse(
      DateValidator.isWithinDateWindow(
        "2026-08-15", startDate: "not-a-date", endDate: "2026-08-24"))
  }

  func testIso8601DueDateInsideWindow() {
    XCTAssertTrue(
      DateValidator.isWithinDateWindow(
        "2026-08-11T15:30:00Z", startDate: "2026-08-10", endDate: "2026-08-24"))
  }

  func testIso8601DueDateOutsideWindow() {
    XCTAssertFalse(
      DateValidator.isWithinDateWindow(
        "2026-08-25T00:00:00Z", startDate: "2026-08-10", endDate: "2026-08-24"))
  }

  func testTSeparatedDateTimeShape() {
    XCTAssertTrue(
      DateValidator.isWithinDateWindow(
        "2026-08-15T09:00:00", startDate: "2026-08-10", endDate: "2026-08-24"))
  }
}

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

  func testFractionalSecondsIsoDueDateInsideWindow() {
    // Matches the project's syncISO8601 format (fractional seconds).
    XCTAssertTrue(
      DateValidator.isWithinDateWindow(
        "2026-08-11T15:30:00.123Z", startDate: "2026-08-10", endDate: "2026-08-24"))
  }


  func testDateBoundsOverloadMatchesStringVersion() {
    let start = try? DateValidator.validateDate("2026-08-10")
    let end = try? DateValidator.validateDate("2026-08-24")
    guard let start, let end else {
      return XCTFail("Failed to parse bounds")
    }

    XCTAssertTrue(
      DateValidator.isWithinDateWindow("2026-08-11 09:00:00", start: start, end: end))
    XCTAssertFalse(
      DateValidator.isWithinDateWindow("2026-08-24 00:00:00", start: start, end: end))
  }

  func testInvalidIso8601DueDateIsExcluded() {
    XCTAssertFalse(
      DateValidator.isWithinDateWindow(
        "2026-02-30T00:00:00Z", startDate: "2026-03-01", endDate: "2026-03-03"))
  }

  func testInvertedWindowRejectedByValidateDateRange() {
    let start = try? DateValidator.validateDate("2026-08-24")
    let end = try? DateValidator.validateDate("2026-08-10")
    guard let start, let end else {
      return XCTFail("Failed to parse bounds")
    }

    XCTAssertThrowsError(try DateValidator.validateDateRange(start: start, end: end))
  }

  func testValidatedDateWindowRejectsOneSidedBounds() {
    XCTAssertThrowsError(
      try DateValidator.validatedDateWindow(startDate: "2026-08-10", endDate: nil)
    ) { error in
      guard case EventCLIError.invalidInput = error else {
        XCTFail("Expected invalidInput error, got: \(error)")
        return
      }
    }
  }

  func testValidatedDateWindowRejectsInvertedBounds() {
    XCTAssertThrowsError(
      try DateValidator.validatedDateWindow(
        startDate: "2026-08-24", endDate: "2026-08-10")
    ) { error in
      guard case EventCLIError.invalidDateRange = error else {
        XCTFail("Expected invalidDateRange error, got: \(error)")
        return
      }
    }
  }
}

import EventModels
import XCTest

@testable import event

final class DateValidatorTests: XCTestCase {

  // MARK: - validateDateTime

  func testValidateDateTimeValid() {
    let dateString = "2026-03-08 14:30:00"
    XCTAssertNoThrow(try DateValidator.validateDateTime(dateString))
  }

  func testValidateDateTimeInvalidFormat() {
    let dateString = "2026/03/08 14:30:00"
    XCTAssertThrowsError(try DateValidator.validateDateTime(dateString)) { error in
      guard case EventCLIError.invalidDate = error else {
        XCTFail("Expected invalidDate error, got: \(error)")
        return
      }
    }
  }

  func testValidateDateTimeAutoCorrectionRejection() {
    XCTAssertThrowsError(try DateValidator.validateDateTime("2026-02-30 14:30:00")) { error in
      guard case EventCLIError.invalidDate = error else {
        XCTFail("Expected invalidDate error, got: \(error)")
        return
      }
    }
  }

  func testConvertDateTimePreservesInstantAcrossTimeZones() throws {
    let newYork = TimeZone(identifier: "America/New_York")!
    let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

    let converted = try DateValidator.convertDateTime(
      "2026-03-10 14:00:00",
      from: newYork,
      to: losAngeles
    )

    XCTAssertEqual(converted, "2026-03-10 11:00:00")
  }

  // MARK: - validateDate

  func testValidateDateValid() {
    let dateString = "2026-03-08"
    XCTAssertNoThrow(try DateValidator.validateDate(dateString))
  }

  func testValidateDateInvalidFormat() {
    let dateString = "03-08-2026"
    XCTAssertThrowsError(try DateValidator.validateDate(dateString)) { error in
      guard case EventCLIError.invalidDate = error else {
        XCTFail("Expected invalidDate error")
        return
      }
    }
  }

  func testValidateDateAutoCorrectionRejection() {
    XCTAssertThrowsError(try DateValidator.validateDate("2026-04-31")) { error in
      guard case EventCLIError.invalidDate = error else {
        XCTFail("Expected invalidDate error, got: \(error)")
        return
      }
    }
  }

  // MARK: - isValidDate

  func testIsValidDate() {
    XCTAssertTrue(DateValidator.isValidDate(year: 2026, month: 3, day: 8))
    XCTAssertTrue(DateValidator.isValidDate(year: 2024, month: 2, day: 29))  // Leap year

    XCTAssertFalse(DateValidator.isValidDate(year: 2026, month: 2, day: 29))  // Not a leap year
    XCTAssertFalse(DateValidator.isValidDate(year: 2026, month: 4, day: 31))
    XCTAssertFalse(DateValidator.isValidDate(year: 2026, month: 13, day: 1))
  }

  // MARK: - validateDateRange

  func testValidateDateRangeValid() {
    let start = try! DateValidator.validateDate("2026-03-08")
    let end = try! DateValidator.validateDate("2026-03-09")
    XCTAssertNoThrow(try DateValidator.validateDateRange(start: start, end: end))
  }

  func testValidateDateRangeSameDate() {
    let start = try! DateValidator.validateDate("2026-03-08")
    let end = try! DateValidator.validateDate("2026-03-08")
    XCTAssertNoThrow(try DateValidator.validateDateRange(start: start, end: end))
  }

  func testValidateDateRangeInvalid() {
    let start = try! DateValidator.validateDate("2026-03-09")
    let end = try! DateValidator.validateDate("2026-03-08")
    XCTAssertThrowsError(try DateValidator.validateDateRange(start: start, end: end)) { error in
      guard case EventCLIError.invalidDateRange = error else {
        XCTFail("Expected invalidDateRange error")
        return
      }
    }
  }

  // MARK: - validateReasonableDate

  func testValidateReasonableDateValid() {
    let date = try! DateValidator.validateDate("2026-03-08")
    XCTAssertNoThrow(try DateValidator.validateReasonableDate(date))
  }

  func testValidateReasonableDateTooEarly() {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "UTC")
    let date = formatter.date(from: "1899-12-31")!
    XCTAssertThrowsError(try DateValidator.validateReasonableDate(date)) { error in
      guard case EventCLIError.dateOutOfRange = error else {
        XCTFail("Expected dateOutOfRange error, got: \(error)")
        return
      }
    }
  }

  func testValidateReasonableDateTooLate() {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let timeZone = TimeZone(identifier: "UTC")!
    formatter.timeZone = timeZone
    let date = formatter.date(from: "2101-01-01")!
    XCTAssertThrowsError(
      try DateValidator.validateReasonableDate(date, timeZone: timeZone)
    ) { error in
      guard case EventCLIError.dateOutOfRange = error else {
        XCTFail("Expected dateOutOfRange error, got: \(error)")
        return
      }
    }
  }

  func testValidateReasonableDateUsesProvidedTimeZone() {
    let date = ISO8601DateFormatter().date(from: "2101-01-01T00:00:00Z")!
    let timeZone = TimeZone(secondsFromGMT: -12 * 60 * 60)!

    XCTAssertNoThrow(try DateValidator.validateReasonableDate(date, timeZone: timeZone))
    XCTAssertThrowsError(try DateValidator.validateReasonableDate(date, timeZone: .gmt))
  }
}

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
        // February doesn't have 30 days
        let dateString = "2026-02-30 14:30:00"
        do {
            let _ = try DateValidator.validateDateTime(dateString)
            // It might throw invalidDate for bad format or invalidDate for auto-correction, both are fine
            XCTFail("Expected error, but didn't throw")
        } catch EventCLIError.invalidDate(_) {
            // Success
        } catch {
            XCTFail("Expected invalidDate error, got: \(error)")
        }
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
        let dateString = "2026-04-31" // April only has 30 days
        do {
            let _ = try DateValidator.validateDate(dateString)
            XCTFail("Expected error, but didn't throw")
        } catch EventCLIError.invalidDate(_) {
            // Success
        } catch {
            XCTFail("Expected invalidDate error, got: \(error)")
        }
    }

    // MARK: - isValidDate

    func testIsValidDate() {
        XCTAssertTrue(DateValidator.isValidDate(year: 2026, month: 3, day: 8))
        XCTAssertTrue(DateValidator.isValidDate(year: 2024, month: 2, day: 29)) // Leap year

        XCTAssertFalse(DateValidator.isValidDate(year: 2026, month: 2, day: 29)) // Not a leap year
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
        do {
            // Need a valid validatable date that is out of range. 1899-12-31 parses fine,
            // but might format back slightly differently depending on timezone in the formatter.
            // Let's use Date components directly if we're just testing the range validation.
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC") // Fix timezone for consistent test
            let date = formatter.date(from: "1899-12-31")!
            try DateValidator.validateReasonableDate(date)
            XCTFail("Expected error, but didn't throw")
        } catch EventCLIError.dateOutOfRange(_) {
            // Success
        } catch {
            XCTFail("Expected dateOutOfRange error, got: \(error)")
        }
    }

    func testValidateReasonableDateTooLate() {
        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC") // Fix timezone for consistent test
            let date = formatter.date(from: "2101-01-01")!
            try DateValidator.validateReasonableDate(date)
            XCTFail("Expected error, but didn't throw")
        } catch EventCLIError.dateOutOfRange(_) {
            // Success
        } catch {
            XCTFail("Expected dateOutOfRange error, got: \(error)")
        }
    }
}

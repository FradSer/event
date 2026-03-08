import XCTest
@testable import event

final class ErrorHandlingTests: XCTestCase {

    func testPermissionDeniedError() {
        let error = EventCLIError.permissionDenied("Calendar access required")
        XCTAssertEqual(error.errorDescription, "Permission denied: Calendar access required")
    }

    func testNotFoundError() {
        let error = EventCLIError.notFound("Reminder with ID abc123")
        XCTAssertEqual(error.errorDescription, "Not found: Reminder with ID abc123")
    }

    func testInvalidInputError() {
        let error = EventCLIError.invalidInput("Invalid date format")
        XCTAssertEqual(error.errorDescription, "Invalid input: Invalid date format")
    }

    func testEventKitError() {
        let error = EventCLIError.eventKitError("Failed to save reminder")
        XCTAssertEqual(error.errorDescription, "EventKit error: Failed to save reminder")
    }

    func testInvalidDateError() {
        let error = EventCLIError.invalidDate("2026-13-45")
        XCTAssertEqual(error.errorDescription, "Invalid date: 2026-13-45")
    }

    func testInvalidDateRangeError() {
        let error = EventCLIError.invalidDateRange("Start date must be before end date")
        XCTAssertEqual(error.errorDescription, "Invalid date range: Start date must be before end date")
    }

    func testDateOutOfRangeError() {
        let error = EventCLIError.dateOutOfRange("Date must be within 10 years")
        XCTAssertEqual(error.errorDescription, "Date out of range: Date must be within 10 years")
    }

    func testUnknownError() {
        let error = EventCLIError.unknown("Something went wrong")
        XCTAssertEqual(error.errorDescription, "Error: Something went wrong")
    }

    func testErrorFormatterWithCLIError() {
        let error = EventCLIError.notFound("Test item")
        let formatted = ErrorFormatter.format(error)
        XCTAssertEqual(formatted, "Not found: Test item")
    }

    func testErrorFormatterWithGenericError() {
        struct GenericError: Error, LocalizedError {
            var errorDescription: String? { "Generic error occurred" }
        }

        let error = GenericError()
        let formatted = ErrorFormatter.format(error)
        XCTAssertEqual(formatted, "Error: Generic error occurred")
    }
}

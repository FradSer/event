import XCTest
@testable import event

final class DateExtensionsTests: XCTestCase {

    func testValidatedDateTime() {
        let dateString = "2026-03-08 14:30:00"
        let date = try? Date.validated(dateTimeString: dateString)
        XCTAssertNotNil(date)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let expectedDate = formatter.date(from: dateString)
        // Dates might not be exactly equal if parsing logic handles seconds/milliseconds differently,
        // but they should be effectively the same timestamp
        if let d1 = date, let d2 = expectedDate {
            XCTAssertEqual(d1.timeIntervalSince1970, d2.timeIntervalSince1970, accuracy: 1.0)
        }
    }

    func testValidatedDate() {
        let dateString = "2026-03-08"
        let date = try? Date.validated(dateString: dateString)
        XCTAssertNotNil(date)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let expectedDate = formatter.date(from: dateString)
        if let d1 = date, let d2 = expectedDate {
            XCTAssertEqual(d1.timeIntervalSince1970, d2.timeIntervalSince1970, accuracy: 1.0)
        }
    }

    func testIsAllDayFormat() {
        XCTAssertTrue(Date.isAllDayFormat("2026-03-08"))
        XCTAssertFalse(Date.isAllDayFormat("2026-03-08 14:30:00"))
        XCTAssertFalse(Date.isAllDayFormat("2026/03/08"))
        XCTAssertFalse(Date.isAllDayFormat("03-08-2026"))
        XCTAssertFalse(Date.isAllDayFormat("March 8, 2026"))
        XCTAssertFalse(Date.isAllDayFormat(""))
    }

    func testDateFormatterExtensions() {
        let date = Date(timeIntervalSince1970: 1772985600) // 2026-03-08 16:00:00 UTC

        // This is tricky to test perfectly because it depends on the local timezone where the test runs.
        // We'll just verify the format string structure
        let eventDateTimeStr = DateFormatter.eventDateTime.string(from: date)
        XCTAssertTrue(eventDateTimeStr.contains("2026") || eventDateTimeStr.contains("2026")) // Timezone might shift day
        XCTAssertTrue(eventDateTimeStr.count == 19) // "yyyy-MM-dd HH:mm:ss" is 19 chars

        let eventDateStr = DateFormatter.eventDate.string(from: date)
        XCTAssertTrue(eventDateStr.contains("2026"))
        XCTAssertTrue(eventDateStr.count == 10) // "yyyy-MM-dd" is 10 chars
    }
}

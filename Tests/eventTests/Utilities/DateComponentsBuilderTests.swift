import XCTest
@testable import event

final class DateComponentsBuilderTests: XCTestCase {

    func testBuild() {
        // Create a date explicitly so we know its exact components
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let date = formatter.date(from: "2026-03-08 15:45:00")!
        let timeZone = TimeZone(identifier: "UTC")!

        let components = DateComponentsBuilder.build(from: date, timeZone: timeZone)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 8)
        XCTAssertEqual(components.hour, 15)
        XCTAssertEqual(components.minute, 45)
        XCTAssertEqual(components.timeZone, timeZone)
        XCTAssertNil(components.second) // Ensure we only extract requested components
    }

    func testBuildAllDay() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let date = formatter.date(from: "2026-03-08")!
        let timeZone = TimeZone(identifier: "UTC")!

        let components = DateComponentsBuilder.buildAllDay(from: date, timeZone: timeZone)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 8)
        XCTAssertNil(components.hour)
        XCTAssertNil(components.minute)
        XCTAssertNil(components.timeZone) // buildAllDay doesn't set timeZone explicitly on the result
    }

    func testToDate() {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 8
        components.hour = 12
        components.minute = 30
        components.timeZone = TimeZone(identifier: "UTC")

        let date = DateComponentsBuilder.toDate(from: components)
        XCTAssertNotNil(date)

        // Format back to check
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        XCTAssertEqual(formatter.string(from: date!), "2026-03-08 12:30:00")
    }
}

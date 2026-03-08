import XCTest
import EventKit
import CoreLocation
@testable import event

final class AlarmTests: XCTestCase {

    func testAlarmWithRelativeOffset() {
        let ekAlarm = EKAlarm(relativeOffset: -3600) // 1 hour before

        let alarm = Alarm(from: ekAlarm)

        XCTAssertEqual(alarm.relativeOffset, -3600)
        XCTAssertNil(alarm.absoluteDate)
        XCTAssertNil(alarm.locationTrigger)
    }

    func testAlarmWithAbsoluteDate() {
        let date = Date(timeIntervalSince1970: 1735689600) // 2025-01-01
        let ekAlarm = EKAlarm(absoluteDate: date)

        let alarm = Alarm(from: ekAlarm)

        XCTAssertNil(alarm.relativeOffset)
        XCTAssertNotNil(alarm.absoluteDate)
        XCTAssertNil(alarm.locationTrigger)
        XCTAssertTrue(alarm.absoluteDate?.contains("202") ?? false)
    }

    func testAlarmWithLocationTrigger() {
        let structuredLocation = EKStructuredLocation(title: "Home")
        structuredLocation.geoLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        structuredLocation.radius = 100

        let ekAlarm = EKAlarm()
        ekAlarm.structuredLocation = structuredLocation
        ekAlarm.proximity = .enter

        let alarm = Alarm(from: ekAlarm)

        XCTAssertNil(alarm.relativeOffset)
        XCTAssertNil(alarm.absoluteDate)
        XCTAssertNotNil(alarm.locationTrigger)
        XCTAssertEqual(alarm.locationTrigger?.title, "Home")
    }

    func testAlarmTypeDisplay() {
        let ekAlarm = EKAlarm(relativeOffset: -600)

        let alarm = Alarm(from: ekAlarm)

        XCTAssertEqual(alarm.alarmType, "display")
    }

    func testAlarmCodable() throws {
        let ekAlarm = EKAlarm(relativeOffset: -1800)

        let alarm = Alarm(from: ekAlarm)

        let encoder = JSONEncoder()
        let data = try encoder.encode(alarm)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Alarm.self, from: data)

        XCTAssertEqual(decoded.relativeOffset, alarm.relativeOffset)
        XCTAssertEqual(decoded.alarmType, alarm.alarmType)
    }
}

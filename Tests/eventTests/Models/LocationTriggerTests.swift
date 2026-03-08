import XCTest
import EventKit
import CoreLocation
@testable import event

final class LocationTriggerTests: XCTestCase {

    func testLocationTriggerFromEKAlarmEnter() {
        let structuredLocation = EKStructuredLocation(title: "Home")
        structuredLocation.geoLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
        structuredLocation.radius = 100

        let ekAlarm = EKAlarm()
        ekAlarm.structuredLocation = structuredLocation
        ekAlarm.proximity = .enter

        let trigger = LocationTrigger(from: ekAlarm)

        XCTAssertNotNil(trigger)
        XCTAssertEqual(trigger?.title, "Home")
        XCTAssertEqual(trigger?.latitude, 37.7749)
        XCTAssertEqual(trigger?.longitude, -122.4194)
        XCTAssertEqual(trigger?.radius, 100)
        XCTAssertEqual(trigger?.proximity, "enter")
    }

    func testLocationTriggerFromEKAlarmLeave() {
        let structuredLocation = EKStructuredLocation(title: "Office")
        structuredLocation.geoLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
        structuredLocation.radius = 200

        let ekAlarm = EKAlarm()
        ekAlarm.structuredLocation = structuredLocation
        ekAlarm.proximity = .leave

        let trigger = LocationTrigger(from: ekAlarm)

        XCTAssertNotNil(trigger)
        XCTAssertEqual(trigger?.title, "Office")
        XCTAssertEqual(trigger?.proximity, "leave")
    }

    func testLocationTriggerFromEKAlarmNoLocation() {
        let ekAlarm = EKAlarm()
        let trigger = LocationTrigger(from: ekAlarm)

        XCTAssertNil(trigger)
    }

    func testLocationTriggerToEKStructuredLocationEnter() {
        let structuredLocation = EKStructuredLocation(title: "Store")
        structuredLocation.geoLocation = CLLocation(latitude: 34.0522, longitude: -118.2437)
        structuredLocation.radius = 150

        let ekAlarm = EKAlarm()
        ekAlarm.structuredLocation = structuredLocation
        ekAlarm.proximity = .enter

        guard let trigger = LocationTrigger(from: ekAlarm) else {
            XCTFail("Failed to create LocationTrigger")
            return
        }

        let (location, proximity) = trigger.toEKStructuredLocation()

        XCTAssertEqual(location.title, "Store")
        XCTAssertEqual(location.geoLocation?.coordinate.latitude, 34.0522)
        XCTAssertEqual(location.geoLocation?.coordinate.longitude, -118.2437)
        XCTAssertEqual(location.radius, 150)
        XCTAssertEqual(proximity, EKAlarmProximity.enter)
    }

    func testLocationTriggerToEKStructuredLocationLeave() {
        let structuredLocation = EKStructuredLocation(title: "Gym")
        structuredLocation.geoLocation = CLLocation(latitude: 51.5074, longitude: -0.1278)
        structuredLocation.radius = 100

        let ekAlarm = EKAlarm()
        ekAlarm.structuredLocation = structuredLocation
        ekAlarm.proximity = .leave

        guard let trigger = LocationTrigger(from: ekAlarm) else {
            XCTFail("Failed to create LocationTrigger")
            return
        }

        let (_, proximity) = trigger.toEKStructuredLocation()

        XCTAssertEqual(proximity, EKAlarmProximity.leave)
    }

    func testLocationTriggerCodable() throws {
        let structuredLocation = EKStructuredLocation(title: "Test Location")
        structuredLocation.geoLocation = CLLocation(latitude: 35.6762, longitude: 139.6503)
        structuredLocation.radius = 250

        let ekAlarm = EKAlarm()
        ekAlarm.structuredLocation = structuredLocation
        ekAlarm.proximity = .enter

        guard let trigger = LocationTrigger(from: ekAlarm) else {
            XCTFail("Failed to create LocationTrigger")
            return
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(trigger)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LocationTrigger.self, from: data)

        XCTAssertEqual(decoded.title, trigger.title)
        XCTAssertEqual(decoded.latitude, trigger.latitude)
        XCTAssertEqual(decoded.longitude, trigger.longitude)
        XCTAssertEqual(decoded.radius, trigger.radius)
        XCTAssertEqual(decoded.proximity, trigger.proximity)
    }
}

import CoreLocation
import EventKit
import XCTest

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

  // MARK: - fromCLI

  func testFromCLIReturnsNilWhenNothingProvided() throws {
    // Given no location-related CLI options
    // When building from CLI
    let trigger = try LocationTrigger.fromCLI(
      name: nil, latitude: nil, longitude: nil, radius: nil, proximity: nil
    )

    // Then no trigger is created
    XCTAssertNil(trigger)
  }

  func testFromCLIAppliesDefaultsForRadiusAndProximity() throws {
    // Given only the required triplet
    // When building from CLI
    let trigger = try LocationTrigger.fromCLI(
      name: "Home", latitude: 22.5431, longitude: 114.0579, radius: nil, proximity: nil
    )

    // Then defaults are applied (100m, enter)
    XCTAssertEqual(trigger?.title, "Home")
    XCTAssertEqual(trigger?.latitude, 22.5431)
    XCTAssertEqual(trigger?.longitude, 114.0579)
    XCTAssertEqual(trigger?.radius, 100)
    XCTAssertEqual(trigger?.proximity, "enter")
  }

  func testFromCLIHonorsExplicitRadiusAndProximity() throws {
    // Given a full CLI option set with leave + custom radius
    // When building from CLI
    let trigger = try LocationTrigger.fromCLI(
      name: "Office", latitude: 40.7128, longitude: -74.0060, radius: 250, proximity: "LEAVE"
    )

    // Then values are honored and proximity is normalized to lowercase
    XCTAssertEqual(trigger?.radius, 250)
    XCTAssertEqual(trigger?.proximity, "leave")
  }

  func testFromCLIFallsBackToDefaultRadiusWhenNonPositive() throws {
    // Given a non-positive radius
    // When building from CLI
    let trigger = try LocationTrigger.fromCLI(
      name: "Home", latitude: 22.5431, longitude: 114.0579, radius: 0, proximity: nil
    )

    // Then the radius falls back to the 100m default (matches EKAlarm coercion)
    XCTAssertEqual(trigger?.radius, 100)
  }

  func testFromCLIThrowsWhenLatitudeIsMissing() {
    // Given location name and longitude only
    // When building from CLI
    // Then an invalidInput error is thrown
    XCTAssertThrowsError(
      try LocationTrigger.fromCLI(
        name: "Home", latitude: nil, longitude: 114.0579, radius: nil, proximity: nil
      )
    ) { error in
      guard case EventCLIError.invalidInput = error else {
        XCTFail("Expected EventCLIError.invalidInput, got \(error)")
        return
      }
    }
  }

  func testFromCLIThrowsWhenOnlyRadiusProvided() {
    // Given only a radius value (an obvious mis-invocation)
    // When building from CLI
    // Then an invalidInput error is thrown
    XCTAssertThrowsError(
      try LocationTrigger.fromCLI(
        name: nil, latitude: nil, longitude: nil, radius: 200, proximity: nil
      )
    ) { error in
      guard case EventCLIError.invalidInput = error else {
        XCTFail("Expected EventCLIError.invalidInput, got \(error)")
        return
      }
    }
  }

  func testFromCLIThrowsOnInvalidProximityValue() {
    // Given an unsupported proximity value
    // When building from CLI
    // Then an invalidInput error is thrown
    XCTAssertThrowsError(
      try LocationTrigger.fromCLI(
        name: "Home",
        latitude: 22.5431,
        longitude: 114.0579,
        radius: nil,
        proximity: "near"
      )
    ) { error in
      guard case EventCLIError.invalidInput = error else {
        XCTFail("Expected EventCLIError.invalidInput, got \(error)")
        return
      }
    }
  }

  func testFromCLIRoundTripsThroughEKStructuredLocation() throws {
    // Given a trigger built from CLI
    // When converting to EKStructuredLocation + EKAlarm and back
    let trigger = try XCTUnwrap(
      LocationTrigger.fromCLI(
        name: "Home",
        latitude: 22.5431,
        longitude: 114.0579,
        radius: 150,
        proximity: "enter"
      )
    )

    let (structuredLocation, proximity) = trigger.toEKStructuredLocation()
    let alarm = EKAlarm()
    alarm.structuredLocation = structuredLocation
    alarm.proximity = proximity

    let roundTripped = try XCTUnwrap(LocationTrigger(from: alarm))

    // Then every field is preserved
    XCTAssertEqual(roundTripped.title, "Home")
    XCTAssertEqual(roundTripped.latitude, 22.5431)
    XCTAssertEqual(roundTripped.longitude, 114.0579)
    XCTAssertEqual(roundTripped.radius, 150)
    XCTAssertEqual(roundTripped.proximity, "enter")
  }
}

import ArgumentParser
import CoreLocation
import EventKit
import XCTest

@testable import event

final class LocationTriggerTests: XCTestCase {

  // MARK: - init?(from: EKAlarm)

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
    XCTAssertEqual(trigger?.proximity, .enter)
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
    XCTAssertEqual(trigger?.proximity, .leave)
  }

  func testLocationTriggerFromEKAlarmNoLocation() {
    let ekAlarm = EKAlarm()
    let trigger = LocationTrigger(from: ekAlarm)

    XCTAssertNil(trigger)
  }

  func testLocationTriggerFromEKAlarmNoneProximityRejected() {
    // Given an EKAlarm carrying a structured location but proximity = .none.
    // EventKit treats `.none` as "no proximity trigger" — it isn't a location alarm
    // we can faithfully represent.
    let structuredLocation = EKStructuredLocation(title: "Home")
    structuredLocation.geoLocation = CLLocation(latitude: 37.7749, longitude: -122.4194)
    structuredLocation.radius = 100

    let ekAlarm = EKAlarm()
    ekAlarm.structuredLocation = structuredLocation
    ekAlarm.proximity = .none

    XCTAssertNil(LocationTrigger(from: ekAlarm))
  }

  // MARK: - toEKAlarm()

  func testLocationTriggerToEKAlarmEnter() throws {
    let trigger = LocationTrigger(
      title: "Store",
      latitude: 34.0522,
      longitude: -118.2437,
      radius: 150,
      proximity: .enter
    )

    let alarm = trigger.toEKAlarm()

    let location = try XCTUnwrap(alarm.structuredLocation)
    XCTAssertEqual(location.title, "Store")
    XCTAssertEqual(location.geoLocation?.coordinate.latitude, 34.0522)
    XCTAssertEqual(location.geoLocation?.coordinate.longitude, -118.2437)
    XCTAssertEqual(location.radius, 150)
    XCTAssertEqual(alarm.proximity, EKAlarmProximity.enter)
  }

  func testLocationTriggerToEKAlarmLeave() {
    let trigger = LocationTrigger(
      title: "Gym",
      latitude: 51.5074,
      longitude: -0.1278,
      radius: 100,
      proximity: .leave
    )

    XCTAssertEqual(trigger.toEKAlarm().proximity, EKAlarmProximity.leave)
  }

  // MARK: - Codable + radius sanitization

  func testLocationTriggerCodable() throws {
    let trigger = LocationTrigger(
      title: "Test Location",
      latitude: 35.6762,
      longitude: 139.6503,
      radius: 250,
      proximity: .enter
    )

    let encoded = try JSONEncoder().encode(trigger)
    let decoded = try JSONDecoder().decode(LocationTrigger.self, from: encoded)

    XCTAssertEqual(decoded.title, trigger.title)
    XCTAssertEqual(decoded.latitude, trigger.latitude)
    XCTAssertEqual(decoded.longitude, trigger.longitude)
    XCTAssertEqual(decoded.radius, trigger.radius)
    XCTAssertEqual(decoded.proximity, trigger.proximity)
  }

  func testLocationTriggerInitClampsNonPositiveRadius() {
    // Both zero and negative radii fall back to the default — matches EKAlarm's
    // behavior of treating non-positive radii as "no radius set".
    for badRadius: Double in [0, -50] {
      let trigger = LocationTrigger(
        title: "Home",
        latitude: 22.5431,
        longitude: 114.0579,
        radius: badRadius,
        proximity: .enter
      )
      XCTAssertEqual(
        trigger.radius, LocationTrigger.defaultRadius,
        "radius=\(badRadius) should clamp to default"
      )
    }
  }

  // MARK: - LocationOptions.resolveTrigger (CLI flag parsing)

  func testLocationOptionsReturnsNilWhenNothingProvided() throws {
    // Given no location flags
    let options = try ReminderCommands.LocationOptions.parse([])

    // When resolving
    let trigger = try options.resolveTrigger()

    // Then no trigger is created and isPresent is false
    XCTAssertFalse(options.isPresent)
    XCTAssertNil(trigger)
  }

  func testLocationOptionsAppliesDefaultsForRadiusAndProximity() throws {
    // Given the required triplet only
    let options = try ReminderCommands.LocationOptions.parse([
      "--location", "Home",
      "--latitude", "22.5431",
      "--longitude", "114.0579",
    ])

    // When resolving
    let trigger = try XCTUnwrap(options.resolveTrigger())

    // Then defaults are applied (100m, enter)
    XCTAssertEqual(trigger.title, "Home")
    XCTAssertEqual(trigger.latitude, 22.5431)
    XCTAssertEqual(trigger.longitude, 114.0579)
    XCTAssertEqual(trigger.radius, LocationTrigger.defaultRadius)
    XCTAssertEqual(trigger.proximity, .enter)
  }

  func testLocationOptionsHonorsExplicitRadiusAndProximity() throws {
    // Given a full CLI option set with LEAVE (mixed case) + custom radius
    // (negative coords use `--name=value` form so ArgumentParser doesn't read the leading
    // `-` as another flag).
    let options = try ReminderCommands.LocationOptions.parse([
      "--location", "Office",
      "--latitude", "40.7128",
      "--longitude=-74.0060",
      "--radius", "250",
      "--proximity", "LEAVE",
    ])

    // When resolving
    let trigger = try XCTUnwrap(options.resolveTrigger())

    // Then values are honored and proximity is lowercased before lookup
    XCTAssertEqual(trigger.radius, 250)
    XCTAssertEqual(trigger.proximity, .leave)
  }

  func testLocationOptionsFallsBackToDefaultRadiusWhenNonPositive() throws {
    // Given a non-positive radius, the model-level clamp keeps it at the default.
    let options = try ReminderCommands.LocationOptions.parse([
      "--location", "Home",
      "--latitude", "22.5431",
      "--longitude", "114.0579",
      "--radius", "0",
    ])

    let trigger = try XCTUnwrap(options.resolveTrigger())

    XCTAssertEqual(trigger.radius, LocationTrigger.defaultRadius)
  }

  func testLocationOptionsThrowsWhenLatitudeIsMissing() throws {
    // Given location name + longitude but no latitude
    let options = try ReminderCommands.LocationOptions.parse([
      "--location", "Home",
      "--longitude", "114.0579",
    ])

    XCTAssertTrue(options.isPresent)
    XCTAssertThrowsError(try options.resolveTrigger()) { error in
      guard case EventCLIError.invalidInput = error else {
        XCTFail("Expected EventCLIError.invalidInput, got \(error)")
        return
      }
    }
  }

  func testLocationOptionsThrowsWhenOnlyRadiusProvided() throws {
    // Given only --radius (an obvious mis-invocation)
    let options = try ReminderCommands.LocationOptions.parse(["--radius", "200"])

    XCTAssertTrue(options.isPresent)
    XCTAssertThrowsError(try options.resolveTrigger()) { error in
      guard case EventCLIError.invalidInput = error else {
        XCTFail("Expected EventCLIError.invalidInput, got \(error)")
        return
      }
    }
  }

  func testLocationOptionsRejectsLatitudeOutOfRange() throws {
    // Given a latitude above the geographic maximum
    let options = try ReminderCommands.LocationOptions.parse([
      "--location", "Home",
      "--latitude", "91",
      "--longitude", "114.0579",
    ])

    XCTAssertThrowsError(try options.resolveTrigger()) { error in
      guard case EventCLIError.invalidInput(let message) = error else {
        XCTFail("Expected EventCLIError.invalidInput, got \(error)")
        return
      }
      XCTAssertTrue(message.contains("latitude"), "Error should mention latitude: \(message)")
    }
  }

  func testLocationOptionsRejectsLongitudeOutOfRange() throws {
    // Given a longitude below the geographic minimum (use `--name=value` so the
    // leading `-` isn't parsed as a flag).
    let options = try ReminderCommands.LocationOptions.parse([
      "--location", "Home",
      "--latitude", "22.5431",
      "--longitude=-181",
    ])

    XCTAssertThrowsError(try options.resolveTrigger()) { error in
      guard case EventCLIError.invalidInput(let message) = error else {
        XCTFail("Expected EventCLIError.invalidInput, got \(error)")
        return
      }
      XCTAssertTrue(message.contains("longitude"), "Error should mention longitude: \(message)")
    }
  }

  func testLocationOptionsAcceptsBoundaryCoordinates() throws {
    // Exact boundary values are valid (geographic poles, antimeridian).
    let options = try ReminderCommands.LocationOptions.parse([
      "--location", "Pole",
      "--latitude", "90",
      "--longitude", "180",
    ])

    let trigger = try XCTUnwrap(options.resolveTrigger())
    XCTAssertEqual(trigger.latitude, 90)
    XCTAssertEqual(trigger.longitude, 180)
  }

  func testLocationOptionsThrowsOnInvalidProximityValue() throws {
    // Given an unsupported proximity value
    let options = try ReminderCommands.LocationOptions.parse([
      "--location", "Home",
      "--latitude", "22.5431",
      "--longitude", "114.0579",
      "--proximity", "near",
    ])

    XCTAssertThrowsError(try options.resolveTrigger()) { error in
      guard case EventCLIError.invalidInput = error else {
        XCTFail("Expected EventCLIError.invalidInput, got \(error)")
        return
      }
    }
  }

  func testLocationOptionsRoundTripsThroughEKAlarm() throws {
    // Given a trigger built from CLI flags
    let options = try ReminderCommands.LocationOptions.parse([
      "--location", "Home",
      "--latitude", "22.5431",
      "--longitude", "114.0579",
      "--radius", "150",
      "--proximity", "enter",
    ])
    let trigger = try XCTUnwrap(options.resolveTrigger())

    // When converting to EKAlarm and back
    let roundTripped = try XCTUnwrap(LocationTrigger(from: trigger.toEKAlarm()))

    // Then every field is preserved
    XCTAssertEqual(roundTripped.title, "Home")
    XCTAssertEqual(roundTripped.latitude, 22.5431)
    XCTAssertEqual(roundTripped.longitude, 114.0579)
    XCTAssertEqual(roundTripped.radius, 150)
    XCTAssertEqual(roundTripped.proximity, .enter)
  }
}

import CoreLocation
import EventKit
import XCTest

@testable import event

/// Service-level tests that operate on in-memory `EKReminder` objects.
/// `EKReminder` can be constructed without Reminders permission as long as we
/// never call `eventStore.save(...)`.
final class ReminderServiceTests: XCTestCase {

  // MARK: - removeLocationAlarms

  func testRemoveLocationAlarmsPreservesTimeBasedAlarms() throws {
    // Given a reminder with one time-based alarm and one location-based alarm…
    let store = EKEventStore()
    let reminder = EKReminder(eventStore: store)
    reminder.title = "Mixed alarms"

    let timeAlarm = EKAlarm(relativeOffset: -600)  // 10 minutes before
    reminder.addAlarm(timeAlarm)

    let structuredLocation = EKStructuredLocation(title: "Home")
    structuredLocation.geoLocation = CLLocation(latitude: 22.5431, longitude: 114.0579)
    structuredLocation.radius = 100
    let locationAlarm = EKAlarm()
    locationAlarm.structuredLocation = structuredLocation
    locationAlarm.proximity = .enter
    reminder.addAlarm(locationAlarm)

    XCTAssertEqual(reminder.alarms?.count, 2)

    // When the location alarms are removed…
    ReminderService.removeLocationAlarms(from: reminder)

    // …only the time-based alarm remains, with its offset intact.
    let remaining = reminder.alarms ?? []
    XCTAssertEqual(remaining.count, 1)
    XCTAssertNil(remaining.first?.structuredLocation)
    XCTAssertEqual(remaining.first?.relativeOffset, -600)
  }

  func testRemoveLocationAlarmsHandlesNoAlarms() {
    // Given a reminder with no alarms at all, the helper is a no-op.
    let store = EKEventStore()
    let reminder = EKReminder(eventStore: store)
    reminder.title = "No alarms"

    ReminderService.removeLocationAlarms(from: reminder)

    XCTAssertTrue(reminder.alarms?.isEmpty ?? true)
  }

  func testRemoveLocationAlarmsHandlesOnlyLocationAlarms() {
    // Given a reminder with only location-based alarms, all of them are cleared.
    let store = EKEventStore()
    let reminder = EKReminder(eventStore: store)
    reminder.title = "Location only"

    for title in ["Home", "Office"] {
      let location = EKStructuredLocation(title: title)
      location.geoLocation = CLLocation(latitude: 22.5431, longitude: 114.0579)
      location.radius = 100
      let alarm = EKAlarm()
      alarm.structuredLocation = location
      alarm.proximity = .enter
      reminder.addAlarm(alarm)
    }
    XCTAssertEqual(reminder.alarms?.count, 2)

    ReminderService.removeLocationAlarms(from: reminder)

    XCTAssertTrue(reminder.alarms?.isEmpty ?? true)
  }

  func testRemoveLocationAlarmsHandlesMultipleLocationAlarms() {
    // Given a reminder with one time-based alarm and two location-based alarms,
    // every location alarm is removed but the time-based one survives.
    let store = EKEventStore()
    let reminder = EKReminder(eventStore: store)
    reminder.title = "Multiple location alarms"

    reminder.addAlarm(EKAlarm(relativeOffset: -300))

    for title in ["Home", "Office"] {
      let location = EKStructuredLocation(title: title)
      location.geoLocation = CLLocation(latitude: 22.5431, longitude: 114.0579)
      location.radius = 100
      let alarm = EKAlarm()
      alarm.structuredLocation = location
      alarm.proximity = .enter
      reminder.addAlarm(alarm)
    }
    XCTAssertEqual(reminder.alarms?.count, 3)

    ReminderService.removeLocationAlarms(from: reminder)

    let remaining = reminder.alarms ?? []
    XCTAssertEqual(remaining.count, 1)
    XCTAssertNil(remaining.first?.structuredLocation)
    XCTAssertEqual(remaining.first?.relativeOffset, -300)
  }
}

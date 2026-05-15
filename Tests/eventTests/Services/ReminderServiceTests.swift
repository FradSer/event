import EventKit
import XCTest

@testable import event

/// Service-level tests that operate on in-memory `EKReminder` objects.
/// `EKReminder` can be constructed without Reminders permission as long as we
/// never call `eventStore.save(...)`.
final class ReminderServiceTests: XCTestCase {

  /// Shared store — `EKEventStore()` is non-trivial to construct, and these tests
  /// only need it as the required `EKReminder.init` dependency, never as an I/O sink.
  private lazy var store = EKEventStore()

  // MARK: - Helpers

  private func makeReminder(title: String) -> EKReminder {
    let reminder = EKReminder(eventStore: store)
    reminder.title = title
    return reminder
  }

  private func makeLocationAlarm(title: String) -> EKAlarm {
    LocationTrigger(
      title: title,
      latitude: 22.5431,
      longitude: 114.0579,
      radius: 100,
      proximity: .enter
    ).toEKAlarm()
  }

  // MARK: - removeLocationAlarms

  func testRemoveLocationAlarmsPreservesTimeBasedAlarms() throws {
    // Given a reminder with one time-based alarm and one location-based alarm…
    let reminder = makeReminder(title: "Mixed alarms")
    reminder.addAlarm(EKAlarm(relativeOffset: -600))  // 10 minutes before
    reminder.addAlarm(makeLocationAlarm(title: "Home"))
    XCTAssertEqual(reminder.alarms?.count, 2)

    // When the location alarms are removed…
    reminder.removeLocationAlarms()

    // …only the time-based alarm remains, with its offset intact.
    let remaining = reminder.alarms ?? []
    XCTAssertEqual(remaining.count, 1)
    XCTAssertNil(remaining.first?.structuredLocation)
    XCTAssertEqual(remaining.first?.relativeOffset, -600)
  }

  func testRemoveLocationAlarmsHandlesNoAlarms() {
    // Given a reminder with no alarms at all, the helper is a no-op.
    let reminder = makeReminder(title: "No alarms")

    reminder.removeLocationAlarms()

    XCTAssertTrue(reminder.alarms?.isEmpty ?? true)
  }

  func testRemoveLocationAlarmsHandlesOnlyLocationAlarms() {
    // Given a reminder with only location-based alarms, all of them are cleared.
    let reminder = makeReminder(title: "Location only")
    reminder.addAlarm(makeLocationAlarm(title: "Home"))
    reminder.addAlarm(makeLocationAlarm(title: "Office"))
    XCTAssertEqual(reminder.alarms?.count, 2)

    reminder.removeLocationAlarms()

    XCTAssertTrue(reminder.alarms?.isEmpty ?? true)
  }

  func testRemoveLocationAlarmsHandlesMultipleLocationAlarms() {
    // Given a reminder with one time-based alarm and two location-based alarms,
    // every location alarm is removed but the time-based one survives.
    let reminder = makeReminder(title: "Multiple location alarms")
    reminder.addAlarm(EKAlarm(relativeOffset: -300))
    reminder.addAlarm(makeLocationAlarm(title: "Home"))
    reminder.addAlarm(makeLocationAlarm(title: "Office"))
    XCTAssertEqual(reminder.alarms?.count, 3)

    reminder.removeLocationAlarms()

    let remaining = reminder.alarms ?? []
    XCTAssertEqual(remaining.count, 1)
    XCTAssertNil(remaining.first?.structuredLocation)
    XCTAssertEqual(remaining.first?.relativeOffset, -300)
  }
}

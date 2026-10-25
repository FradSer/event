#if canImport(EventKit)
  import EventKit
  import EventModels
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

    // MARK: - reminderDateComponents

    func testDateOnlyDueDateProducesAllDayComponents() throws {
      // A date without a time is EventKit's all-day representation: no hour, no minute.
      let components = try ReminderService.reminderDateComponents(from: "2026-08-26")

      XCTAssertEqual(components.year, 2026)
      XCTAssertEqual(components.month, 8)
      XCTAssertEqual(components.day, 26)
      XCTAssertNil(components.hour)
      XCTAssertNil(components.minute)
    }

    func testDateTimeDueDateKeepsTimeComponents() throws {
      let components = try ReminderService.reminderDateComponents(from: "2026-08-26 14:30:00")

      XCTAssertEqual(components.year, 2026)
      XCTAssertEqual(components.month, 8)
      XCTAssertEqual(components.day, 26)
      XCTAssertEqual(components.hour, 14)
      XCTAssertEqual(components.minute, 30)
    }

    func testMidnightDueDateStaysTimed() throws {
      // "00:00:00" is an explicit time, so it must not collapse into an all-day reminder.
      let components = try ReminderService.reminderDateComponents(from: "2026-08-26 00:00:00")

      XCTAssertEqual(components.hour, 0)
      XCTAssertEqual(components.minute, 0)
    }

    func testInvalidDueDateThrows() {
      XCTAssertThrowsError(try ReminderService.reminderDateComponents(from: "26.08.2026"))
    }

    // MARK: - Reminder mapping

    func testAllDayReminderIsReadBackAsDateOnly() {
      let reminder = makeReminder(title: "All-day")
      reminder.dueDateComponents = DateComponents(year: 2026, month: 8, day: 26)

      let mapped = Reminder(from: reminder)

      XCTAssertEqual(mapped.dueDate, "2026-08-26")
    }

    func testTimedReminderIsReadBackWithTime() {
      let reminder = makeReminder(title: "Timed")
      reminder.dueDateComponents = DateComponents(
        year: 2026, month: 8, day: 26, hour: 14, minute: 30)

      let mapped = Reminder(from: reminder)

      XCTAssertEqual(mapped.dueDate, "2026-08-26 14:30:00")
    }
  }
#endif

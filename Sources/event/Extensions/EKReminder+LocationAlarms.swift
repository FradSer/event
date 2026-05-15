import EventKit

// MARK: - Reminder Location Alarms

extension EKReminder {
  /// Remove every alarm attached to this reminder whose alarm has a structured location,
  /// leaving time-based alarms intact.
  ///
  /// Snapshots the alarms first so the underlying array is not mutated during iteration.
  func removeLocationAlarms() {
    let locationAlarms = alarms?.filter { $0.structuredLocation != nil } ?? []
    for alarm in locationAlarms {
      removeAlarm(alarm)
    }
  }
}

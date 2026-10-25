#if canImport(EventKit)

  import EventKit
  import EventModels

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

    /// Replace the repeat rule. EventKit will not save one on a reminder without a due
    /// date, so that is checked here for a readable error.
    func setRecurrenceRule(_ rule: RecurrenceRule) throws {
      guard dueDateComponents != nil else {
        throw EventCLIError.invalidInput("A repeat rule needs a due date; set --due as well.")
      }
      recurrenceRules = [try rule.toEKRecurrenceRule()]
    }
  }

#endif

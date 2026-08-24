#if canImport(EventKit)

  import EventKit
  import EventModels
  import Foundation

  extension Reminder {
    init(from ekReminder: EKReminder, preferredTimeZone: TimeZone = .current) {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
      formatter.timeZone = preferredTimeZone

      let dateOnlyFormatter = DateFormatter()
      dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
      dateOnlyFormatter.timeZone = preferredTimeZone

      // Components without an hour are how EventKit represents an all-day reminder.
      // Rendering them as "00:00:00" would turn every all-day reminder into a timed
      // one as soon as the value is written back.
      let format: (DateComponents) -> String? = { components in
        DateComponentsBuilder.toDate(from: components, timeZone: preferredTimeZone).map { date in
          components.hour == nil
            ? dateOnlyFormatter.string(from: date)
            : formatter.string(from: date)
        }
      }

      let dueDate = ekReminder.dueDateComponents.flatMap(format)
      let startDate = ekReminder.startDateComponents.flatMap(format)

      let alarms = ekReminder.alarms?.map { Alarm(from: $0, preferredTimeZone: preferredTimeZone) }
      let recurrenceRules = ekReminder.recurrenceRules?.map { RecurrenceRule(from: $0) }
      let locationTrigger = ekReminder.alarms?.compactMap { LocationTrigger(from: $0) }.first

      let utcFormatter = ISO8601DateFormatter.syncISO8601

      self.init(
        id: ekReminder.calendarItemIdentifier,
        title: ekReminder.title ?? "",
        isCompleted: ekReminder.isCompleted,
        isFlagged: false,  // EKReminder has no isFlagged property
        list: ekReminder.calendar?.title ?? "Unknown",
        notes: ekReminder.notes,
        url: ekReminder.url?.absoluteString,
        location: ekReminder.location,
        timeZone: ekReminder.timeZone?.identifier,
        dueDate: dueDate,
        startDate: startDate,
        completionDate: ekReminder.completionDate.map { utcFormatter.string(from: $0) },
        creationDate: ekReminder.creationDate.map { utcFormatter.string(from: $0) },
        lastModifiedDate: ekReminder.lastModifiedDate.map { utcFormatter.string(from: $0) },
        externalId: ekReminder.calendarItemExternalIdentifier,
        priority: ekReminder.priority,
        alarms: alarms,
        recurrenceRules: recurrenceRules,
        locationTrigger: locationTrigger
      )
    }
  }

#endif

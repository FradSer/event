import EventKit
import EventModels
import Foundation

extension Reminder {
  init(from ekReminder: EKReminder, preferredTimeZone: TimeZone = .current) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    formatter.timeZone = preferredTimeZone

    let dueDate = ekReminder.dueDateComponents.flatMap { components in
      DateComponentsBuilder.toDate(from: components, timeZone: preferredTimeZone)
    }.map { formatter.string(from: $0) }

    let startDate = ekReminder.startDateComponents.flatMap { components in
      DateComponentsBuilder.toDate(from: components, timeZone: preferredTimeZone)
    }.map { formatter.string(from: $0) }

    let alarms = ekReminder.alarms?.map { Alarm(from: $0, preferredTimeZone: preferredTimeZone) }
    let recurrenceRules = ekReminder.recurrenceRules?.map { RecurrenceRule(from: $0) }
    let locationTrigger = ekReminder.alarms?.compactMap { LocationTrigger(from: $0) }.first

    let utcFormatter = DateFormatter.eventISO8601

    self.init(
      id: ekReminder.calendarItemIdentifier,
      title: ekReminder.title ?? "",
      isCompleted: ekReminder.isCompleted,
      isFlagged: ekReminder.isFlagged,
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

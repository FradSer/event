import AppleSyncKit
import EventModels
import XCTest

final class CalendarEventSyncTests: XCTestCase {
  func testTimedSyncDateRangeUsesEventTimeZone() throws {
    let event = CalendarEvent(
      id: "event-1",
      title: "Late meeting",
      calendar: "Calendar",
      startDate: "2026-03-10 23:30:00",
      endDate: "2026-03-11 00:30:00",
      isAllDay: false,
      location: nil,
      notes: nil,
      url: nil,
      timeZone: "America/Los_Angeles",
      creationDate: nil,
      lastModifiedDate: nil,
      status: nil,
      availability: nil,
      alarms: nil,
      recurrenceRules: nil,
      attendees: nil
    )

    let range = event.syncDateRange()

    XCTAssertEqual(range.start, "2026-03-11T06:30:00.000Z")
    XCTAssertEqual(range.end, "2026-03-11T07:30:00.000Z")
    XCTAssertTrue(
      range.overlaps(
        SyncDateRange(
          start: "2026-03-11T00:00:00.000Z",
          end: "2026-03-11T23:59:59.000Z"
        ))
    )
  }

  func testCalendarEventSnapshotIncludesTimeZoneChanges() throws {
    let base = CalendarEvent(
      id: "event-1",
      title: "Meeting",
      calendar: "Calendar",
      startDate: "2026-03-10 14:00:00",
      endDate: "2026-03-10 15:00:00",
      isAllDay: false,
      location: nil,
      notes: nil,
      url: nil,
      timeZone: "America/New_York",
      creationDate: nil,
      lastModifiedDate: nil,
      status: nil,
      availability: nil,
      alarms: nil,
      recurrenceRules: nil,
      attendees: nil
    )
    let changed = CalendarEvent(
      id: base.id,
      title: base.title,
      calendar: base.calendar,
      startDate: base.startDate,
      endDate: base.endDate,
      isAllDay: base.isAllDay,
      location: base.location,
      notes: base.notes,
      url: base.url,
      timeZone: "America/Los_Angeles",
      creationDate: base.creationDate,
      lastModifiedDate: base.lastModifiedDate,
      status: base.status,
      availability: base.availability,
      alarms: base.alarms,
      recurrenceRules: base.recurrenceRules,
      attendees: base.attendees
    )

    let baseSnapshot = try SyncSnapshotEncoder.encode(
      base, volatileKeys: calendarEventSnapshotVolatileKeys)
    let changedSnapshot = try SyncSnapshotEncoder.encode(
      changed, volatileKeys: calendarEventSnapshotVolatileKeys)

    XCTAssertNotEqual(baseSnapshot, changedSnapshot)
  }
}

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

  func testLegacySyncDateRangeUsesMachineTimeZone() throws {
    let event = CalendarEvent(
      id: "legacy-event",
      title: "Legacy meeting",
      calendar: "Calendar",
      startDate: "2026-03-10 14:00:00",
      endDate: "2026-03-10 15:00:00",
      isAllDay: false,
      location: nil,
      notes: nil,
      url: nil,
      timeZone: "America/New_York",
      dateFormatVersion: nil,
      creationDate: nil,
      lastModifiedDate: nil,
      status: nil,
      availability: nil,
      alarms: nil,
      recurrenceRules: nil,
      attendees: nil
    )

    let range = event.syncDateRange()
    let expectedStart = try DateValidator.validateDateTime(
      event.startDate, timeZone: .current)
    let expectedEnd = try DateValidator.validateDateTime(event.endDate, timeZone: .current)

    XCTAssertEqual(range.start, ISO8601DateFormatter.syncISO8601.string(from: expectedStart))
    XCTAssertEqual(range.end, ISO8601DateFormatter.syncISO8601.string(from: expectedEnd))
    XCTAssertNil(event.syncTimeZoneIdentifier)
    XCTAssertFalse(event.shouldClearTimeZoneOnSync)
  }

  func testLegacyCalendarEventDecodesWithoutDateFormatVersion() throws {
    let current = CalendarEvent(
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
    let encoded = try JSONEncoder().encode(current)
    var object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object.removeValue(forKey: "dateFormatVersion")
    let legacyData = try JSONSerialization.data(withJSONObject: object)

    let decoded = try JSONDecoder().decode(CalendarEvent.self, from: legacyData)

    XCTAssertNil(decoded.dateFormatVersion)
    XCTAssertNil(decoded.syncTimeZoneIdentifier)
  }

  func testCalendarEventSnapshotIncludesDateFormatVersionChanges() throws {
    let current = CalendarEvent(
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
    let legacy = CalendarEvent(
      id: current.id,
      title: current.title,
      calendar: current.calendar,
      startDate: current.startDate,
      endDate: current.endDate,
      isAllDay: current.isAllDay,
      location: current.location,
      notes: current.notes,
      url: current.url,
      timeZone: current.timeZone,
      dateFormatVersion: nil,
      creationDate: current.creationDate,
      lastModifiedDate: current.lastModifiedDate,
      status: current.status,
      availability: current.availability,
      alarms: current.alarms,
      recurrenceRules: current.recurrenceRules,
      attendees: current.attendees
    )

    let currentSnapshot = try SyncSnapshotEncoder.encode(
      current, volatileKeys: calendarEventSnapshotVolatileKeys)
    let legacySnapshot = try SyncSnapshotEncoder.encode(
      legacy, volatileKeys: calendarEventSnapshotVolatileKeys)

    XCTAssertNotEqual(currentSnapshot, legacySnapshot)
  }
}

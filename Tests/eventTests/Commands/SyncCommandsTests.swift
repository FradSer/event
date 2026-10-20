import AppleSyncKit
import EventModels
import EventSync
import XCTest

@testable import event

final class SyncCommandsTests: XCTestCase {
  func testFullPullOrderCreatesListsBeforeReminders() {
    XCTAssertEqual(SyncEntityType.fullPullOrder, [.lists, .reminders, .calendar])
  }

  func testFullSyncMapsToDependencyOrderedEntities() {
    XCTAssertEqual(
      SyncEntityType.all.syncEntities,
      [.reminderLists, .reminders, .calendarEvents])
  }

  func testSelectiveSyncMapsToOneEntity() {
    XCTAssertEqual(SyncEntityType.reminders.syncEntities, [.reminders])
    XCTAssertEqual(SyncEntityType.calendar.syncEntities, [.calendarEvents])
    XCTAssertEqual(SyncEntityType.lists.syncEntities, [.reminderLists])
  }

  func testBatchSyncOrdersAreStable() {
    XCTAssertEqual(SyncEntity.pullOrder, [.reminderLists, .reminders, .calendarEvents])
    XCTAssertEqual(SyncEntity.pushOrder, [.reminders, .calendarEvents, .reminderLists])
  }

  func testCalendarWindowDeletionPreservesOnlyCandidateTimestamps() {
    let timestamps = ["inside": "2026-01-01", "outside": "2026-01-02"]

    let filtered = EventKitCalendarSyncSource.deletionTimestamps(timestamps, for: ["inside"])

    XCTAssertEqual(filtered, ["inside": "2026-01-01"])
  }

  func testUnrepresentablePulledURLSuppressesLocalPushes() throws {
    let item = makeCalendarEvent(availability: nil, alarms: nil, url: "ftp://example.com/x")
    var state = SyncEntityState()
    try state.recordSyncedValue(
      item,
      remoteId: "remote-event-1",
      lastModified: "2026-10-21T00:00:00Z",
      volatileKeys: calendarEventSnapshotVolatileKeys
    )

    try EventKitCalendarSyncSource.recordURLPushability(
      for: item, remoteId: "remote-event-1", state: &state)

    XCTAssertFalse(EventKitCalendarSyncSource.canPush(remoteId: "remote-event-1", state: state))
  }

  func testRepresentablePulledURLAllowsLocalPushes() throws {
    let item = makeCalendarEvent(
      availability: nil, alarms: nil, url: "https://example.com/event")
    var state = SyncEntityState()
    try state.recordSyncedValue(
      item,
      remoteId: "remote-event-1",
      lastModified: "2026-10-21T00:00:00Z",
      volatileKeys: calendarEventSnapshotVolatileKeys
    )

    try EventKitCalendarSyncSource.recordURLPushability(
      for: item, remoteId: "remote-event-1", state: &state)

    XCTAssertTrue(EventKitCalendarSyncSource.canPush(remoteId: "remote-event-1", state: state))
  }

  func testRepresentablePullReplacesUnsupportedURLPushMarker() throws {
    let unsupported = makeCalendarEvent(
      availability: nil, alarms: nil, url: "ftp://example.com/x")
    let supported = makeCalendarEvent(
      availability: nil, alarms: nil, url: "https://example.com/event")
    var state = SyncEntityState()
    try state.recordSyncedValue(
      unsupported,
      remoteId: "remote-event-1",
      lastModified: "2026-10-21T00:00:00Z",
      volatileKeys: calendarEventSnapshotVolatileKeys
    )
    try EventKitCalendarSyncSource.recordURLPushability(
      for: unsupported, remoteId: "remote-event-1", state: &state)
    XCTAssertFalse(EventKitCalendarSyncSource.canPush(remoteId: "remote-event-1", state: state))

    try state.recordSyncedValue(
      supported,
      remoteId: "remote-event-1",
      lastModified: "2026-10-21T00:01:00Z",
      volatileKeys: calendarEventSnapshotVolatileKeys
    )
    try EventKitCalendarSyncSource.recordURLPushability(
      for: supported, remoteId: "remote-event-1", state: &state)

    XCTAssertTrue(EventKitCalendarSyncSource.canPush(remoteId: "remote-event-1", state: state))
  }

  func testCalendarSyncWriteFieldsCarrySupportedAvailabilityAndRelativeAlarms() {
    let item = makeCalendarEvent(
      availability: "busy",
      alarms: [
        Alarm(relativeOffset: -900, absoluteDate: nil, locationTrigger: nil, alarmType: "display"),
        Alarm(relativeOffset: -3600, absoluteDate: nil, locationTrigger: nil, alarmType: nil),
      ])

    let fields = EventKitCalendarSyncSource.writeFields(for: item)

    XCTAssertEqual(fields.availability?.rawValue, "busy")
    XCTAssertEqual(fields.alarmMinutes, [15, 60])
  }

  func testCalendarSyncWriteFieldsIgnoreUnsupportedAvailabilityAndAlarms() {
    let item = makeCalendarEvent(
      availability: "notSupported",
      alarms: [
        Alarm(
          relativeOffset: nil, absoluteDate: "2026-10-20T09:00:00Z", locationTrigger: nil,
          alarmType: "display")
      ])

    let fields = EventKitCalendarSyncSource.writeFields(for: item)

    XCTAssertNil(fields.availability)
    XCTAssertNil(fields.alarmMinutes)
  }

  func testCalendarSyncWriteFieldsDistinguishMissingAndClearedAlarms() {
    let missing = EventKitCalendarSyncSource.writeFields(
      for: makeCalendarEvent(availability: nil, alarms: nil))
    let cleared = EventKitCalendarSyncSource.writeFields(
      for: makeCalendarEvent(availability: nil, alarms: []))

    XCTAssertNil(missing.alarmMinutes)
    XCTAssertEqual(cleared.alarmMinutes, [])
  }

  private func makeCalendarEvent(
    availability: String?, alarms: [Alarm]?, url: String? = nil
  ) -> CalendarEvent {
    CalendarEvent(
      id: "event-1",
      title: "Meeting",
      calendar: "Work",
      startDate: "2026-10-20 09:00:00",
      endDate: "2026-10-20 10:00:00",
      isAllDay: false,
      location: nil,
      notes: nil,
      url: url,
      timeZone: "America/Los_Angeles",
      creationDate: nil,
      lastModifiedDate: nil,
      status: nil,
      availability: availability,
      alarms: alarms,
      recurrenceRules: nil,
      attendees: nil
    )
  }
}

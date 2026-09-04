import AppleSyncKit
import EventModels
import XCTest

@testable import EventSync

final class LinuxEventSyncSourceTests: XCTestCase {
  func testRecordsDateRangeMetadataUnderRemoteId() {
    let event = CalendarEvent(
      id: "local-event",
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
    var state = SyncEntityState()

    LinuxEventSyncSource.recordDateRange(event, remoteId: "remote-event", state: &state)

    XCTAssertEqual(state.dateRangeByRemoteId["remote-event"], event.syncDateRange())
    XCTAssertNil(state.dateRangeByRemoteId[event.id])
  }
}

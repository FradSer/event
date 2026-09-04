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
}

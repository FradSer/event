import AppleSyncKit
import Foundation
import XCTest

@testable import EventSync

final class SyncJournalMigrationTests: XCTestCase {
  func testConfigStoreUsesConsolidatedJournalPath() {
    XCTAssertTrue(SyncConfigStore.store.syncJournalPath.hasSuffix("/event-sync/sync-state.json"))
  }

  func testJournalStoresEntityKeyedCursors() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ConfigStore(namespace: "event-sync", prefix: "EVENT", rootDirectory: directory)
    let state = SyncJournalState(cursors: [
      "reminders": "r1",
      "calendar_events": "e1",
      "reminder_lists": "l1",
    ])

    try store.journal.commitCheckpoint(state)

    XCTAssertEqual(try store.journal.load(), state)
    let permissions = try XCTUnwrap(
      FileManager.default.attributesOfItem(atPath: store.syncJournalPath)[.posixPermissions]
        as? NSNumber)
    XCTAssertEqual(permissions.intValue & 0o777, 0o600)
  }
}

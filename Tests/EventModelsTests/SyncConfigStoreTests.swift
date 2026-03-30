import EventModels
import XCTest

final class SyncConfigStoreTests: XCTestCase {
  func testSyncConfigCodable() throws {
    let config = SyncConfig(
      apiURL: "https://example.workers.dev",
      apiToken: "test-token",
      deviceId: "test-device"
    )
    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(SyncConfig.self, from: data)
    XCTAssertEqual(decoded.apiURL, config.apiURL)
    XCTAssertEqual(decoded.apiToken, config.apiToken)
    XCTAssertEqual(decoded.deviceId, config.deviceId)
  }

  func testSyncCursorsCodable() throws {
    let cursors = SyncCursors(
      reminders: "2026-03-25T10:00:00",
      calendarEvents: "2026-03-25T09:00:00",
      reminderLists: nil
    )
    let data = try JSONEncoder().encode(cursors)
    let decoded = try JSONDecoder().decode(SyncCursors.self, from: data)
    XCTAssertEqual(decoded.reminders, cursors.reminders)
    XCTAssertEqual(decoded.calendarEvents, cursors.calendarEvents)
    XCTAssertNil(decoded.reminderLists)
  }
}

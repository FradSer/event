import XCTest

@testable import EventSync

final class SyncLastRunTests: XCTestCase {
  func testCodableRoundTrip() throws {
    let lastRun = SyncLastRun(
      finishedAt: Date(timeIntervalSince1970: 1_700_000_000),
      succeeded: true,
      error: nil,
      summary: ["Reminders: pulled 1, deleted 0, skipped 0", "Reminders: synced 3, skipped 2"])
    let data = try JSONEncoder().encode(lastRun)
    let decoded = try JSONDecoder().decode(SyncLastRun.self, from: data)
    XCTAssertEqual(decoded.finishedAt, lastRun.finishedAt)
    XCTAssertTrue(decoded.succeeded)
    XCTAssertNil(decoded.error)
    XCTAssertEqual(decoded.summary, lastRun.summary)
  }

  func testCodableRoundTripWithError() throws {
    let lastRun = SyncLastRun(
      finishedAt: Date(timeIntervalSince1970: 1_700_000_000),
      succeeded: false,
      error: "Error: connection failed",
      summary: [])
    let decoded = try JSONDecoder().decode(
      SyncLastRun.self, from: JSONEncoder().encode(lastRun))
    XCTAssertFalse(decoded.succeeded)
    XCTAssertEqual(decoded.error, "Error: connection failed")
  }
}

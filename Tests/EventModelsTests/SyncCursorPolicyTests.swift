import EventModels
import XCTest

final class SyncCursorPolicyTests: XCTestCase {
  func testNextCursorDoesNotAdvanceWhenPageHasFailures() {
    let next = SyncCursorPolicy.nextCursor(
      currentCursor: "2026-03-27T12:00:00|a",
      responseCursor: "2026-03-27T12:05:00|z",
      hadFailures: true
    )

    XCTAssertEqual(next, "2026-03-27T12:00:00|a")
  }

  func testNextCursorAdvancesWhenPageSucceeds() {
    let next = SyncCursorPolicy.nextCursor(
      currentCursor: "2026-03-27T12:00:00|a",
      responseCursor: "2026-03-27T12:05:00|z",
      hadFailures: false
    )

    XCTAssertEqual(next, "2026-03-27T12:05:00|z")
  }

  func testNextCursorUsesResponseWhenCurrentIsNilAndNoFailures() {
    let next = SyncCursorPolicy.nextCursor(
      currentCursor: nil,
      responseCursor: "2026-03-27T12:05:00|z",
      hadFailures: false
    )

    XCTAssertEqual(next, "2026-03-27T12:05:00|z")
  }

  func testNextCursorFallsBackToResponseWhenCurrentIsNilWithFailures() {
    let next = SyncCursorPolicy.nextCursor(
      currentCursor: nil,
      responseCursor: "2026-03-27T12:05:00|z",
      hadFailures: true
    )

    XCTAssertEqual(next, "2026-03-27T12:05:00|z")
  }
}

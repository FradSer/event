import EventModels
import XCTest

@testable import EventSync

private struct ReminderPayload: Codable, Equatable {
  let title: String
}

final class PullItemDecoderTests: XCTestCase {
  func testDecodeItemsSucceedsWithValidData() throws {
    let items = [
      PullItemDTO(
        id: "r1",
        data: .object(["title": .string("Buy milk")]),
        deleted: false,
        updatedAt: "2026-03-27T12:00:00Z"
      ),
      PullItemDTO(
        id: "r2",
        data: .object(["title": .string("Walk dog")]),
        deleted: true,
        updatedAt: "2026-03-27T13:00:00Z"
      ),
    ]

    let decoded: [PullItem<ReminderPayload>] = try PullItemDecoder.decodeItems(
      from: items, entity: "reminders"
    )
    XCTAssertEqual(decoded.count, 2)
    XCTAssertEqual(decoded[0].data.title, "Buy milk")
    XCTAssertEqual(decoded[0].id, "r1")
    XCTAssertFalse(decoded[0].deleted)
    XCTAssertEqual(decoded[1].data.title, "Walk dog")
    XCTAssertTrue(decoded[1].deleted)
  }

  func testDecodeItemsThrowsWhenAnyItemIsMalformed() throws {
    let items = [
      PullItemDTO(
        id: "r1",
        data: .object(["title": .string("ok")]),
        deleted: false,
        updatedAt: "2026-03-27T12:00:00Z"
      ),
      PullItemDTO(
        id: "r2",
        data: .object(["wrong": .string("shape")]),
        deleted: false,
        updatedAt: "2026-03-27T12:01:00Z"
      ),
    ]

    XCTAssertThrowsError(
      try PullItemDecoder.decodeItems(from: items, entity: "reminders")
        as [PullItem<ReminderPayload>]
    )
  }

  func testDecodeEmptyItems() throws {
    let decoded: [PullItem<ReminderPayload>] = try PullItemDecoder.decodeItems(
      from: [], entity: "reminders"
    )
    XCTAssertTrue(decoded.isEmpty)
  }
}

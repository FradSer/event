import XCTest

@testable import event

final class CalendarCommandsTests: XCTestCase {
  func testCreateParsesTimeZone() throws {
    let command = try CalendarCommands.Create.parse([
      "--title", "New York meeting",
      "--start", "2026-08-21 11:00:00",
      "--end", "2026-08-21 12:00:00",
      "--timezone", "America/New_York",
    ])

    XCTAssertEqual(command.timezone, "America/New_York")
  }

  func testUpdateParsesTimeZone() throws {
    let command = try CalendarCommands.Update.parse([
      "--id", "event-id",
      "--timezone", "America/Los_Angeles",
    ])

    XCTAssertEqual(command.timezone, "America/Los_Angeles")
  }
}

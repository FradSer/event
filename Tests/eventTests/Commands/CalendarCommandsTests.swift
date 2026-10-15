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

  func testGetParsesId() throws {
    let command = try CalendarCommands.Get.parse([
      "--id", "563017D1-59C6-4E77-BCD8-E34FC5795538:88976a38-d0a4-366e-a159-170de51c0a56",
      "--json",
    ])

    XCTAssertEqual(
      command.id, "563017D1-59C6-4E77-BCD8-E34FC5795538:88976a38-d0a4-366e-a159-170de51c0a56")
    XCTAssertTrue(command.json)
  }

  func testGetRequiresId() {
    XCTAssertThrowsError(try CalendarCommands.Get.parse([]))
  }

  func testCalendarsParsesJSONFlag() throws {
    let command = try CalendarCommands.Calendars.parse(["--json"])

    XCTAssertTrue(command.json)
  }
}

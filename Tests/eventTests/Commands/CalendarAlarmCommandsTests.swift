import XCTest

@testable import event

/// Tests for the alarm flags on `calendar create` / `calendar update`:
/// parsing of `--alarm` / `--add-alarm` / `--clear-alarms` and the
/// mutual-exclusion validation on update.
///
/// EventKit writes are not exercised here because they would mutate a real
/// calendar. The isolated sync-backend tests cover stored values and clears.
final class CalendarAlarmCommandsTests: XCTestCase {

  private static let createBase = [
    "--title", "Test", "--start", "2027-01-01 10:00:00", "--end", "2027-01-01 11:00:00",
  ]

  // MARK: - create --alarm

  func testCreateParsesMultipleAlarms() throws {
    let cmd = try CalendarCommands.Create.parse(
      Self.createBase + ["--alarm", "15", "--alarm", "60"])
    XCTAssertEqual(cmd.alarm, [15, 60])
  }

  func testCreateDefaultsToNoAlarms() throws {
    let cmd = try CalendarCommands.Create.parse(Self.createBase)
    XCTAssertTrue(cmd.alarm.isEmpty)
  }

  func testCreateParsesURLAndAvailability() throws {
    let cmd = try CalendarCommands.Create.parse(
      Self.createBase + [
        "--url", "https://example.com/event",
        "--availability", "free",
      ])
    XCTAssertEqual(cmd.url, "https://example.com/event")
    XCTAssertEqual(cmd.availability?.rawValue, "free")
  }

  func testCreateRejectsNegativeAlarmMinutes() {
    XCTAssertThrowsError(
      try CalendarCommands.Create.parse(Self.createBase + ["--alarm", "-5"]))
  }

  func testCreateRejectsUnsafeURLScheme() {
    XCTAssertThrowsError(
      try CalendarCommands.Create.parse(Self.createBase + ["--url", "javascript:alert(1)"]))
  }

  // MARK: - update flag parsing

  func testUpdateParsesReplaceAlarms() throws {
    let cmd = try CalendarCommands.Update.parse(["--id", "E1", "--alarm", "5", "--alarm", "30"])
    XCTAssertEqual(cmd.alarm, [5, 30])
    XCTAssertTrue(cmd.addAlarm.isEmpty)
    XCTAssertFalse(cmd.clearAlarms)
  }

  func testUpdateParsesAddAlarm() throws {
    let cmd = try CalendarCommands.Update.parse(["--id", "E1", "--add-alarm", "30"])
    XCTAssertEqual(cmd.addAlarm, [30])
    XCTAssertTrue(cmd.alarm.isEmpty)
  }

  func testUpdateParsesClearAlarms() throws {
    let cmd = try CalendarCommands.Update.parse(["--id", "E1", "--clear-alarms"])
    XCTAssertTrue(cmd.clearAlarms)
  }

  func testUpdateParsesURLAvailabilityAndClearURL() throws {
    let cmd = try CalendarCommands.Update.parse(
      ["--id", "E1", "--url", "https://example.com/event", "--availability", "tentative"])
    XCTAssertEqual(cmd.url, "https://example.com/event")
    XCTAssertEqual(cmd.availability?.rawValue, "tentative")

    let clear = try CalendarCommands.Update.parse(["--id", "E1", "--clear-url"])
    XCTAssertTrue(clear.clearURL)
  }

  func testUpdateRejectsURLAndClearURLTogether() {
    XCTAssertThrowsError(
      try CalendarCommands.Update.parse([
        "--id", "E1", "--url", "https://example.com", "--clear-url",
      ]))
  }

  func testUpdateRejectsNegativeAlarmMinutes() {
    XCTAssertThrowsError(
      try CalendarCommands.Update.parse(["--id", "E1", "--add-alarm", "-5"]))
  }

  // MARK: - update mutual-exclusion validation

  func testUpdateAllowsSingleAlarmMode() {
    XCTAssertNoThrow(try CalendarCommands.Update.parse(["--id", "E1", "--alarm", "15"]))
    XCTAssertNoThrow(try CalendarCommands.Update.parse(["--id", "E1", "--add-alarm", "15"]))
    XCTAssertNoThrow(try CalendarCommands.Update.parse(["--id", "E1", "--clear-alarms"]))
    XCTAssertNoThrow(try CalendarCommands.Update.parse(["--id", "E1"]))
  }

  func testUpdateRejectsReplaceWithAdd() {
    XCTAssertThrowsError(
      try CalendarCommands.Update.parse(["--id", "E1", "--alarm", "15", "--add-alarm", "30"]))
  }

  func testUpdateRejectsReplaceWithClear() {
    XCTAssertThrowsError(
      try CalendarCommands.Update.parse(["--id", "E1", "--alarm", "15", "--clear-alarms"]))
  }

  func testUpdateRejectsAddWithClear() {
    XCTAssertThrowsError(
      try CalendarCommands.Update.parse(["--id", "E1", "--add-alarm", "30", "--clear-alarms"]))
  }
}

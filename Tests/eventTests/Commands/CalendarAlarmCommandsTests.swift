import XCTest

@testable import event

/// Tests for the alarm flags on `calendar create` / `calendar update`:
/// parsing of `--alarm` / `--add-alarm` / `--clear-alarms` and the
/// mutual-exclusion validation on update.
///
/// The EventKit-backed alarm application (EKAlarm creation, replace/append)
/// requires a real calendar + permissions and is verified end-to-end against
/// the built binary rather than here.
final class CalendarAlarmCommandsTests: XCTestCase {

  private static let createBase = [
    "--title", "Test", "--start", "2027-01-01 10:00:00", "--end", "2027-01-01 11:00:00",
  ]

  // MARK: - create --alarm

  func testCreateParsesMultipleAlarms() throws {
    let cmd = try CalendarCommands.Create.parse(Self.createBase + ["--alarm", "15", "--alarm", "60"])
    XCTAssertEqual(cmd.alarm, [15, 60])
  }

  func testCreateDefaultsToNoAlarms() throws {
    let cmd = try CalendarCommands.Create.parse(Self.createBase)
    XCTAssertTrue(cmd.alarm.isEmpty)
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

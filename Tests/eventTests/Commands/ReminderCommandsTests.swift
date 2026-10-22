import XCTest

@testable import event

final class ReminderCommandsTests: XCTestCase {
  func testGetCommandParsesReminderIDAndJSONFlag() throws {
    let command = try EventCLI.parseAsRoot([
      "reminders", "get", "--id", "reminder-id", "--json",
    ])

    XCTAssertEqual((command as? ReminderCommands.Get)?.id, "reminder-id")
    XCTAssertTrue((command as? ReminderCommands.Get)?.json ?? false)
  }

  /// Regression: `--no-shortcuts` used to be declared on the root command as
  /// well as on `reminders create` / `reminders update`. ArgumentParser bound
  /// the flag to the root declaration, so the leaf flag stayed false and the
  /// Shortcut path ran even when the caller disabled it — which put the
  /// Shortcut notes on stdout and broke JSON parsing.
  func testNoShortcutsReachesCreateCommand() throws {
    let command = try EventCLI.parseAsRoot([
      "reminders", "create", "--title", "Test", "--no-shortcuts",
    ])

    XCTAssertTrue((command as? ReminderCommands.Create)?.noShortcuts ?? false)
  }

  func testNoShortcutsReachesUpdateCommand() throws {
    let command = try EventCLI.parseAsRoot([
      "reminders", "update", "--id", "reminder-id", "--no-shortcuts",
    ])

    XCTAssertTrue((command as? ReminderCommands.Update)?.noShortcuts ?? false)
  }

  func testNoShortcutsDefaultsToFalse() throws {
    let command = try EventCLI.parseAsRoot([
      "reminders", "create", "--title", "Test",
    ])

    XCTAssertFalse((command as? ReminderCommands.Create)?.noShortcuts ?? true)
  }
}

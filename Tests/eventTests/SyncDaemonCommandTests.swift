import XCTest

@testable import EventCommands
@testable import event

final class SyncDaemonCommandTests: XCTestCase {
  func testMakeSpecBuildsLabelArgsAndEnvironment() throws {
    let spec = try SyncDaemonCommand.makeSpec(
      interval: 1800,
      environment: ["EVENT_ENCRYPTION_KEY": "test-key"],
      executablePath: "/usr/local/bin/event")
    XCTAssertEqual(spec.label, "ai.fradser.event-sync")
    XCTAssertEqual(
      spec.programArguments, ["/usr/local/bin/event", "sync", "run", "--daemon"])
    XCTAssertEqual(spec.startInterval, 1800)
    XCTAssertEqual(spec.environment["EVENT_ENCRYPTION_KEY"], "test-key")
    XCTAssertNotNil(spec.environment["PATH"])
    XCTAssertTrue(spec.logPath.hasSuffix(".config/event-sync/logs/daemon.log"))
  }

  func testMakeSpecResolvesRelativeExecutablePath() throws {
    let spec = try SyncDaemonCommand.makeSpec(
      interval: 60,
      environment: ["EVENT_ENCRYPTION_KEY": "k"],
      executablePath: "./event")
    XCTAssertTrue(spec.programArguments[0].hasPrefix("/"))
  }

  func testMakeSpecThrowsWithoutEncryptionKey() {
    XCTAssertThrowsError(
      try SyncDaemonCommand.makeSpec(interval: 1800, environment: [:])
    ) { error in
      XCTAssertTrue(error.localizedDescription.contains("EVENT_ENCRYPTION_KEY"))
    }
  }
}

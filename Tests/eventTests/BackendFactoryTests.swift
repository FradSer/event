import AppleSyncKit
import EventModels
import XCTest

@testable import EventSync
@testable import event

#if canImport(EventKit)
  import EventKit
#endif

// MARK: - BackendFactory Tests

final class BackendFactoryTests: XCTestCase {

  // MARK: - Reminders Backend

  func testMakeRemindersBackend() async throws {
    let backend = try await BackendFactory.makeRemindersBackend()
    #if canImport(EventKit)
      XCTAssertTrue(
        backend is ReminderService,
        "macOS should return ReminderService, got \(type(of: backend))"
      )
    #else
      XCTAssertTrue(
        backend is SQLiteReminderService,
        "Linux should return SQLiteReminderService, got \(type(of: backend))"
      )
    #endif
  }

  // MARK: - Calendar Backend

  func testMakeCalendarBackend() async throws {
    let backend = try await BackendFactory.makeCalendarBackend()
    #if canImport(EventKit)
      XCTAssertTrue(
        backend is CalendarService,
        "macOS should return CalendarService, got \(type(of: backend))"
      )
    #else
      XCTAssertTrue(
        backend is SQLiteCalendarService,
        "Linux should return SQLiteCalendarService, got \(type(of: backend))"
      )
    #endif
  }

  // MARK: - Lists Backend

  func testMakeListsBackend() async throws {
    let backend = try await BackendFactory.makeListsBackend()
    #if canImport(EventKit)
      XCTAssertTrue(
        backend is ListService,
        "macOS should return ListService, got \(type(of: backend))"
      )
    #else
      XCTAssertTrue(
        backend is SQLiteListService,
        "Linux should return SQLiteListService, got \(type(of: backend))"
      )
    #endif
  }

  // MARK: - Cloudflare Config Validation

  /// Setting exactly one of the two required connection variables is an error
  /// on every platform. Local backends no longer require config, but sync does.
  func testConfigRequiresBothVariables() throws {
    XCTAssertThrowsError(
      try SyncConfigStore.store.loadFromEnvironment(
        [SyncConfigStore.EnvKey.apiURL: "https://example.com"]
      )
    ) { error in
      guard let syncError = error as? SyncError else {
        XCTFail("Expected SyncError, got \(type(of: error))")
        return
      }
      if case .invalidInput(let message) = syncError {
        XCTAssertTrue(
          message.contains("Both"),
          "Error message should mention both variables are required"
        )
      } else {
        XCTFail("Expected invalidInput, got \(syncError)")
      }
    }
  }
}

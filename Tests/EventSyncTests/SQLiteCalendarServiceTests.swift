import AppleSyncKit
import EventModels
import EventSync
import SQLite
import XCTest

// MARK: - SQLite Calendar Service Tests

final class SQLiteCalendarServiceTests: XCTestCase {
  private var connection: Connection!
  private var service: SQLiteCalendarService!

  override func setUp() async throws {
    // Use an in-memory database for testing
    connection = try Connection(.inMemory)

    // Run migrations
    try connection.execute(
      """
      CREATE TABLE calendar_events (
        id TEXT PRIMARY KEY NOT NULL,
        data TEXT NOT NULL,
        last_modified TEXT NOT NULL,
        deleted INTEGER DEFAULT 0,
        updated_at TEXT DEFAULT (datetime('now')),
        is_local_only INTEGER DEFAULT 0
      )
      """)

    service = SQLiteCalendarService(connection: connection)
  }

  override func tearDown() async throws {
    service = nil
    connection = nil
  }

  // MARK: - Create Tests

  func testCreateEvent() async throws {
    let startDate = ISO8601DateFormatter().string(from: Date())
    let endDate = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))

    let params = CreateEventParams(
      title: "Test Event",
      calendarName: "Test Calendar",
      startDate: startDate,
      endDate: endDate,
      notes: "Test notes"
    )

    let event = try await service.createEvent(params)

    XCTAssertEqual(event.title, "Test Event")
    XCTAssertEqual(event.calendar, "Test Calendar")
    XCTAssertEqual(event.startDate, startDate)
    XCTAssertEqual(event.endDate, endDate)
    XCTAssertEqual(event.notes, "Test notes")
    XCTAssertFalse(event.isAllDay)
    XCTAssertNotNil(event.id)
    XCTAssertNotNil(event.creationDate)
    XCTAssertNotNil(event.lastModifiedDate)

    // Verify it was saved to database
    let fetched = try await service.fetchEvent(byId: event.id)
    XCTAssertEqual(fetched.id, event.id)
    XCTAssertEqual(fetched.title, event.title)
  }

  func testCreateAllDayEvent() async throws {
    let startDate = ISO8601DateFormatter().string(from: Date())
    let endDate = ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400))

    let params = CreateEventParams(
      title: "All Day Event",
      startDate: startDate,
      endDate: endDate,
      isAllDay: true
    )

    let event = try await service.createEvent(params)

    XCTAssertEqual(event.title, "All Day Event")
    XCTAssertTrue(event.isAllDay)
  }

  // MARK: - Fetch Tests

  func testFetchEventsEmpty() async throws {
    let start = ISO8601DateFormatter().string(from: Date())
    let end = ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400 * 7))

    let events = try await service.fetchEvents(start: start, end: end, calendarName: nil)
    XCTAssertTrue(events.isEmpty)
  }

  func testFetchEventsAll() async throws {
    let start = ISO8601DateFormatter().string(from: Date())
    let end = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))

    // Create multiple events
    _ = try await service.createEvent(
      CreateEventParams(title: "E1", calendarName: "Cal1", startDate: start, endDate: end))
    _ = try await service.createEvent(
      CreateEventParams(title: "E2", calendarName: "Cal2", startDate: start, endDate: end))
    _ = try await service.createEvent(
      CreateEventParams(title: "E3", calendarName: "Cal1", startDate: start, endDate: end))

    let rangeStart = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
    let rangeEnd = ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400))

    let events = try await service.fetchEvents(start: rangeStart, end: rangeEnd, calendarName: nil)
    XCTAssertEqual(events.count, 3)
  }

  func testFetchEventsByCalendar() async throws {
    let start = ISO8601DateFormatter().string(from: Date())
    let end = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))

    _ = try await service.createEvent(
      CreateEventParams(title: "E1", calendarName: "Cal1", startDate: start, endDate: end))
    _ = try await service.createEvent(
      CreateEventParams(title: "E2", calendarName: "Cal2", startDate: start, endDate: end))
    _ = try await service.createEvent(
      CreateEventParams(title: "E3", calendarName: "Cal1", startDate: start, endDate: end))

    let rangeStart = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
    let rangeEnd = ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400))

    let cal1Events = try await service.fetchEvents(
      start: rangeStart, end: rangeEnd, calendarName: "Cal1")
    XCTAssertEqual(cal1Events.count, 2)
    XCTAssertTrue(cal1Events.allSatisfy { $0.calendar == "Cal1" })
  }

  func testFetchEventById() async throws {
    let startDate = ISO8601DateFormatter().string(from: Date())
    let endDate = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))

    let created = try await service.createEvent(
      CreateEventParams(title: "Test", startDate: startDate, endDate: endDate))

    let fetched = try await service.fetchEvent(byId: created.id)
    XCTAssertEqual(fetched.id, created.id)
    XCTAssertEqual(fetched.title, created.title)
  }

  func testFetchEventByIdNotFound() async throws {
    do {
      _ = try await service.fetchEvent(byId: "nonexistent-id")
      XCTFail("Should throw notFound error")
    } catch let error as EventCLIError {
      if case .notFound = error {
        // Expected
      } else {
        XCTFail("Expected notFound error, got \(error)")
      }
    }
  }

  // MARK: - Update Tests

  func testUpdateEvent() async throws {
    let startDate = ISO8601DateFormatter().string(from: Date())
    let endDate = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))

    let created = try await service.createEvent(
      CreateEventParams(title: "Original", startDate: startDate, endDate: endDate))

    let updateParams = UpdateEventParams(
      title: "Updated",
      location: "New location",
      notes: "Added notes"
    )

    let updated = try await service.updateEvent(id: created.id, params: updateParams)

    XCTAssertEqual(updated.title, "Updated")
    XCTAssertEqual(updated.location, "New location")
    XCTAssertEqual(updated.notes, "Added notes")
    XCTAssertEqual(updated.startDate, startDate)  // Unchanged
    XCTAssertEqual(updated.endDate, endDate)  // Unchanged
  }

  func testUpdateEventPartial() async throws {
    let startDate = ISO8601DateFormatter().string(from: Date())
    let endDate = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))

    let created = try await service.createEvent(
      CreateEventParams(
        title: "Original",
        calendarName: "Cal1",
        startDate: startDate,
        endDate: endDate,
        notes: "Original notes"
      ))

    // Update only title
    let updateParams = UpdateEventParams(title: "Updated Title")

    let updated = try await service.updateEvent(id: created.id, params: updateParams)

    XCTAssertEqual(updated.title, "Updated Title")
    XCTAssertEqual(updated.notes, "Original notes")  // Unchanged
    XCTAssertEqual(updated.calendar, "Cal1")  // Unchanged
  }

  func testUpdateEventNotFound() async throws {
    let updateParams = UpdateEventParams(title: "Updated")

    do {
      _ = try await service.updateEvent(id: "nonexistent-id", params: updateParams)
      XCTFail("Should throw notFound error")
    } catch let error as EventCLIError {
      if case .notFound = error {
        // Expected
      } else {
        XCTFail("Expected notFound error, got \(error)")
      }
    }
  }

  // MARK: - Delete Tests

  func testDeleteEvent() async throws {
    let startDate = ISO8601DateFormatter().string(from: Date())
    let endDate = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))

    let created = try await service.createEvent(
      CreateEventParams(title: "To Delete", startDate: startDate, endDate: endDate))

    // Verify it exists
    let fetched = try await service.fetchEvent(byId: created.id)
    XCTAssertEqual(fetched.id, created.id)

    // Delete it
    try await service.deleteEvent(id: created.id)

    // Verify it's no longer fetchable (soft delete)
    do {
      _ = try await service.fetchEvent(byId: created.id)
      XCTFail("Should throw notFound error after deletion")
    } catch let error as EventCLIError {
      if case .notFound = error {
        // Expected
      } else {
        XCTFail("Expected notFound error, got \(error)")
      }
    }
  }

  func testDeleteEventNotFound() async throws {
    do {
      try await service.deleteEvent(id: "nonexistent-id")
      XCTFail("Should throw notFound error")
    } catch let error as EventCLIError {
      if case .notFound = error {
        // Expected
      } else {
        XCTFail("Expected notFound error, got \(error)")
      }
    }
  }

  // MARK: - Local Only Flag Tests

  func testCreateEventSetsLocalOnly() async throws {
    let startDate = ISO8601DateFormatter().string(from: Date())
    let endDate = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))

    let event = try await service.createEvent(
      CreateEventParams(title: "Test", startDate: startDate, endDate: endDate))

    // Check database directly
    let isLocalOnly =
      try connection.scalar(
        "SELECT is_local_only FROM calendar_events WHERE id = ?", event.id) as! Int64

    XCTAssertEqual(isLocalOnly, 1)
  }

  func testUpdateEventSetsLocalOnly() async throws {
    let startDate = ISO8601DateFormatter().string(from: Date())
    let endDate = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))

    let created = try await service.createEvent(
      CreateEventParams(title: "Test", startDate: startDate, endDate: endDate))

    // Clear the flag directly (simulating sync)
    try connection.run(
      "UPDATE calendar_events SET is_local_only = 0 WHERE id = ?", created.id)

    // Update the event
    let updateParams = UpdateEventParams(title: "Updated")
    _ = try await service.updateEvent(id: created.id, params: updateParams)

    // Check that flag is set again
    let isLocalOnly =
      try connection.scalar(
        "SELECT is_local_only FROM calendar_events WHERE id = ?", created.id) as! Int64

    XCTAssertEqual(isLocalOnly, 1)
  }
}

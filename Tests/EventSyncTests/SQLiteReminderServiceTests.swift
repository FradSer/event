import AppleSyncKit
import EventModels
import EventSync
import SQLite
import XCTest

// MARK: - SQLite Reminder Service Tests

final class SQLiteReminderServiceTests: XCTestCase {
  private var connection: Connection!
  private var service: SQLiteReminderService!

  override func setUp() async throws {
    // Use an in-memory database for testing
    connection = try Connection(.inMemory)

    // Run migrations
    try connection.execute(
      """
      CREATE TABLE reminders (
        id TEXT PRIMARY KEY NOT NULL,
        data TEXT NOT NULL,
        last_modified TEXT NOT NULL,
        deleted INTEGER DEFAULT 0,
        updated_at TEXT DEFAULT (datetime('now')),
        is_local_only INTEGER DEFAULT 0
      )
      """)

    service = SQLiteReminderService(connection: connection)
  }

  override func tearDown() async throws {
    service = nil
    connection = nil
  }

  // MARK: - Create Tests

  func testCreateReminder() async throws {
    let params = CreateReminderParams(
      title: "Test Reminder",
      listName: "Test List",
      notes: "Test notes",
      priority: 1
    )

    let reminder = try await service.createReminder(params)

    XCTAssertEqual(reminder.title, "Test Reminder")
    XCTAssertEqual(reminder.list, "Test List")
    XCTAssertEqual(reminder.notes, "Test notes")
    XCTAssertEqual(reminder.priority, 1)
    XCTAssertFalse(reminder.isCompleted)
    XCTAssertNotNil(reminder.id)
    XCTAssertNotNil(reminder.creationDate)
    XCTAssertNotNil(reminder.lastModifiedDate)

    // Verify it was saved to database
    let fetched = try await service.fetchReminder(byId: reminder.id)
    XCTAssertEqual(fetched.id, reminder.id)
    XCTAssertEqual(fetched.title, reminder.title)
  }

  func testCreateReminderWithDueDate() async throws {
    let dueDate = ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400))
    let params = CreateReminderParams(
      title: "Due Reminder",
      dueDate: dueDate,
      priority: 0
    )

    let reminder = try await service.createReminder(params)

    XCTAssertEqual(reminder.title, "Due Reminder")
    XCTAssertEqual(reminder.dueDate, dueDate)
  }

  // MARK: - Fetch Tests

  func testFetchRemindersEmpty() async throws {
    let reminders = try await service.fetchReminders(listName: nil, showCompleted: false)
    XCTAssertTrue(reminders.isEmpty)
  }

  func testFetchRemindersAll() async throws {
    // Create multiple reminders
    _ = try await service.createReminder(
      CreateReminderParams(title: "R1", listName: "List1", priority: 0))
    _ = try await service.createReminder(
      CreateReminderParams(title: "R2", listName: "List2", priority: 0))
    _ = try await service.createReminder(
      CreateReminderParams(title: "R3", listName: "List1", priority: 0))

    let reminders = try await service.fetchReminders(listName: nil, showCompleted: true)
    XCTAssertEqual(reminders.count, 3)
  }

  func testFetchRemindersByList() async throws {
    _ = try await service.createReminder(
      CreateReminderParams(title: "R1", listName: "List1", priority: 0))
    _ = try await service.createReminder(
      CreateReminderParams(title: "R2", listName: "List2", priority: 0))
    _ = try await service.createReminder(
      CreateReminderParams(title: "R3", listName: "List1", priority: 0))

    let list1Reminders = try await service.fetchReminders(listName: "List1", showCompleted: true)
    XCTAssertEqual(list1Reminders.count, 2)
    XCTAssertTrue(list1Reminders.allSatisfy { $0.list == "List1" })
  }

  func testFetchRemindersHideCompleted() async throws {
    let r1 = try await service.createReminder(
      CreateReminderParams(title: "R1", priority: 0))
    _ = try await service.createReminder(
      CreateReminderParams(title: "R2", priority: 0))

    // Complete r1
    let updateParams = UpdateReminderParams(
      completed: true
    )
    _ = try await service.updateReminder(id: r1.id, params: updateParams)

    // Fetch without completed
    let incompleteReminders = try await service.fetchReminders(
      listName: nil, showCompleted: false)
    XCTAssertEqual(incompleteReminders.count, 1)
    XCTAssertEqual(incompleteReminders[0].title, "R2")

    // Fetch with completed
    let allReminders = try await service.fetchReminders(listName: nil, showCompleted: true)
    XCTAssertEqual(allReminders.count, 2)
  }

  func testFetchReminderById() async throws {
    let created = try await service.createReminder(
      CreateReminderParams(title: "Test", priority: 0))

    let fetched = try await service.fetchReminder(byId: created.id)
    XCTAssertEqual(fetched.id, created.id)
    XCTAssertEqual(fetched.title, created.title)
  }

  func testFetchReminderByIdNotFound() async throws {
    do {
      _ = try await service.fetchReminder(byId: "nonexistent-id")
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

  func testUpdateReminder() async throws {
    let created = try await service.createReminder(
      CreateReminderParams(title: "Original", priority: 0))

    let updateParams = UpdateReminderParams(
      title: "Updated",
      completed: true,
      notes: "Added notes",
      priority: 5
    )

    let updated = try await service.updateReminder(id: created.id, params: updateParams)

    XCTAssertEqual(updated.title, "Updated")
    XCTAssertTrue(updated.isCompleted)
    XCTAssertEqual(updated.notes, "Added notes")
    XCTAssertEqual(updated.priority, 5)
  }

  func testUpdateReminderPartial() async throws {
    let created = try await service.createReminder(
      CreateReminderParams(
        title: "Original",
        listName: "List1",
        notes: "Original notes",
        priority: 1
      ))

    // Update only title
    let updateParams = UpdateReminderParams(
      title: "Updated Title"
    )

    let updated = try await service.updateReminder(id: created.id, params: updateParams)

    XCTAssertEqual(updated.title, "Updated Title")
    XCTAssertEqual(updated.notes, "Original notes")  // Unchanged
    XCTAssertEqual(updated.list, "List1")  // Unchanged
    XCTAssertEqual(updated.priority, 1)  // Unchanged
  }

  func testUpdateReminderNotFound() async throws {
    let updateParams = UpdateReminderParams(
      title: "Updated"
    )

    do {
      _ = try await service.updateReminder(id: "nonexistent-id", params: updateParams)
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

  func testDeleteReminder() async throws {
    let created = try await service.createReminder(
      CreateReminderParams(title: "To Delete", priority: 0))

    // Verify it exists
    let fetched = try await service.fetchReminder(byId: created.id)
    XCTAssertEqual(fetched.id, created.id)

    // Delete it
    try await service.deleteReminder(id: created.id)

    // Verify it's no longer fetchable (soft delete)
    do {
      _ = try await service.fetchReminder(byId: created.id)
      XCTFail("Should throw notFound error after deletion")
    } catch let error as EventCLIError {
      if case .notFound = error {
        // Expected
      } else {
        XCTFail("Expected notFound error, got \(error)")
      }
    }
  }

  func testDeleteReminderNotFound() async throws {
    do {
      try await service.deleteReminder(id: "nonexistent-id")
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

  func testCreateReminderSetsLocalOnly() async throws {
    let reminder = try await service.createReminder(
      CreateReminderParams(title: "Test", priority: 0))

    // Check database directly
    let isLocalOnly =
      try connection.scalar(
        "SELECT is_local_only FROM reminders WHERE id = ?", reminder.id) as! Int64

    XCTAssertEqual(isLocalOnly, 1)
  }

  func testUpdateReminderSetsLocalOnly() async throws {
    let created = try await service.createReminder(
      CreateReminderParams(title: "Test", priority: 0))

    // Clear the flag directly (simulating sync)
    try connection.run(
      "UPDATE reminders SET is_local_only = 0 WHERE id = ?", created.id)

    // Update the reminder
    let updateParams = UpdateReminderParams(title: "Updated")
    _ = try await service.updateReminder(id: created.id, params: updateParams)

    // Check that flag is set again
    let isLocalOnly =
      try connection.scalar(
        "SELECT is_local_only FROM reminders WHERE id = ?", created.id) as! Int64

    XCTAssertEqual(isLocalOnly, 1)
  }
}

import AppleSyncKit
import EventModels
import EventSync
import SQLite
import XCTest

// MARK: - SQLite List Service Tests

final class SQLiteListServiceTests: XCTestCase {
  private var connection: Connection!
  private var service: SQLiteListService!

  override func setUp() async throws {
    // Use an in-memory database for testing
    connection = try Connection(.inMemory)

    // Run migrations
    try connection.execute(
      """
      CREATE TABLE reminder_lists (
        id TEXT PRIMARY KEY NOT NULL,
        data TEXT NOT NULL,
        last_modified TEXT NOT NULL,
        deleted INTEGER DEFAULT 0,
        updated_at TEXT DEFAULT (datetime('now')),
        is_local_only INTEGER DEFAULT 0
      )
      """)

    service = SQLiteListService(connection: connection)
  }

  override func tearDown() async throws {
    service = nil
    connection = nil
  }

  // MARK: - Create Tests

  func testCreateList() async throws {
    let list = try await service.createList(title: "Test List", color: "#FF0000")

    XCTAssertEqual(list.title, "Test List")
    XCTAssertEqual(list.color, "#FF0000")
    XCTAssertFalse(list.isImmutable)
    XCTAssertNotNil(list.id)

    // Verify it was saved to database
    let lists = try await service.fetchLists()
    XCTAssertEqual(lists.count, 1)
    XCTAssertEqual(lists[0].id, list.id)
    XCTAssertEqual(lists[0].title, list.title)
  }

  func testCreateListWithoutColor() async throws {
    let list = try await service.createList(title: "No Color List", color: nil)

    XCTAssertEqual(list.title, "No Color List")
    XCTAssertNil(list.color)
  }

  func testCreateMultipleLists() async throws {
    _ = try await service.createList(title: "List 1", color: nil)
    _ = try await service.createList(title: "List 2", color: "#00FF00")
    _ = try await service.createList(title: "List 3", color: "#0000FF")

    let lists = try await service.fetchLists()
    XCTAssertEqual(lists.count, 3)
  }

  // MARK: - Fetch Tests

  func testFetchListsEmpty() async throws {
    let lists = try await service.fetchLists()
    XCTAssertTrue(lists.isEmpty)
  }

  func testFetchListsOrdered() async throws {
    _ = try await service.createList(title: "Zebra", color: nil)
    _ = try await service.createList(title: "Apple", color: nil)
    _ = try await service.createList(title: "Mango", color: nil)

    let lists = try await service.fetchLists()
    XCTAssertEqual(lists.count, 3)
    XCTAssertEqual(lists[0].title, "Apple")
    XCTAssertEqual(lists[1].title, "Mango")
    XCTAssertEqual(lists[2].title, "Zebra")
  }

  func testFetchListsExcludesDeleted() async throws {
    let list1 = try await service.createList(title: "Active", color: nil)
    let list2 = try await service.createList(title: "Deleted", color: nil)

    // Delete list2
    try await service.deleteList(id: list2.id)

    let lists = try await service.fetchLists()
    XCTAssertEqual(lists.count, 1)
    XCTAssertEqual(lists[0].id, list1.id)
  }

  // MARK: - Update Tests

  func testUpdateListTitle() async throws {
    let created = try await service.createList(title: "Original", color: "#FF0000")

    let updated = try await service.updateList(id: created.id, title: "Updated", color: nil)

    XCTAssertEqual(updated.title, "Updated")
    XCTAssertEqual(updated.color, "#FF0000")  // Unchanged
    XCTAssertEqual(updated.id, created.id)
  }

  func testUpdateListColor() async throws {
    let created = try await service.createList(title: "Original", color: "#FF0000")

    let updated = try await service.updateList(id: created.id, title: nil, color: "#00FF00")

    XCTAssertEqual(updated.title, "Original")  // Unchanged
    XCTAssertEqual(updated.color, "#00FF00")
  }

  func testUpdateListBoth() async throws {
    let created = try await service.createList(title: "Original", color: "#FF0000")

    let updated = try await service.updateList(
      id: created.id,
      title: "Updated",
      color: "#00FF00"
    )

    XCTAssertEqual(updated.title, "Updated")
    XCTAssertEqual(updated.color, "#00FF00")
  }

  func testUpdateListNotFound() async throws {
    do {
      _ = try await service.updateList(id: "nonexistent-id", title: "Updated", color: nil)
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

  func testDeleteList() async throws {
    let created = try await service.createList(title: "To Delete", color: nil)

    // Verify it exists
    var lists = try await service.fetchLists()
    XCTAssertEqual(lists.count, 1)
    XCTAssertEqual(lists[0].id, created.id)

    // Delete it
    try await service.deleteList(id: created.id)

    // Verify it's no longer fetchable (soft delete)
    lists = try await service.fetchLists()
    XCTAssertEqual(lists.count, 0)
  }

  func testDeleteListNotFound() async throws {
    do {
      try await service.deleteList(id: "nonexistent-id")
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

  func testCreateListSetsLocalOnly() async throws {
    let list = try await service.createList(title: "Test", color: nil)

    // Check database directly
    let isLocalOnly =
      try connection.scalar(
        "SELECT is_local_only FROM reminder_lists WHERE id = ?", list.id) as! Int64

    XCTAssertEqual(isLocalOnly, 1)
  }

  func testUpdateListSetsLocalOnly() async throws {
    let created = try await service.createList(title: "Test", color: nil)

    // Clear the flag directly (simulating sync)
    try connection.run(
      "UPDATE reminder_lists SET is_local_only = 0 WHERE id = ?", created.id)

    // Update the list
    _ = try await service.updateList(id: created.id, title: "Updated", color: nil)

    // Check that flag is set again
    let isLocalOnly =
      try connection.scalar(
        "SELECT is_local_only FROM reminder_lists WHERE id = ?", created.id) as! Int64

    XCTAssertEqual(isLocalOnly, 1)
  }

  func testDeleteListSetsLocalOnly() async throws {
    let created = try await service.createList(title: "Test", color: nil)

    // Clear the flag directly (simulating sync)
    try connection.run(
      "UPDATE reminder_lists SET is_local_only = 0 WHERE id = ?", created.id)

    // Delete the list
    try await service.deleteList(id: created.id)

    // Check that both deleted and is_local_only flags are set
    let deleted =
      try connection.scalar(
        "SELECT deleted FROM reminder_lists WHERE id = ?", created.id) as! Int64
    let isLocalOnly =
      try connection.scalar(
        "SELECT is_local_only FROM reminder_lists WHERE id = ?", created.id) as! Int64

    XCTAssertEqual(deleted, 1)
    XCTAssertEqual(isLocalOnly, 1)
  }
}

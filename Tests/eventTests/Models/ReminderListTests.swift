#if canImport(EventKit)
  import EventKit
  import EventModels
  import XCTest

  @testable import event

  final class ReminderListTests: XCTestCase {

    private let store = EKEventStore()

    func testReminderListInitialization() {
      let ekCalendar = EKCalendar(for: .reminder, eventStore: store)
      ekCalendar.title = "My List"

      let reminderList = ReminderList(from: ekCalendar)

      XCTAssertEqual(reminderList.title, "My List")
      XCTAssertFalse(reminderList.id.isEmpty)
    }

    func testReminderListImmutable() {
      let ekCalendar = EKCalendar(for: .reminder, eventStore: store)
      ekCalendar.title = "Immutable List"

      let reminderList = ReminderList(from: ekCalendar)

      XCTAssertEqual(reminderList.isImmutable, ekCalendar.isImmutable)
    }

    func testReminderListCodable() throws {
      let ekCalendar = EKCalendar(for: .reminder, eventStore: store)
      ekCalendar.title = "Test List"

      let reminderList = ReminderList(from: ekCalendar)

      let data = try JSONEncoder().encode(reminderList)
      let decoded = try JSONDecoder().decode(ReminderList.self, from: data)

      XCTAssertEqual(decoded.id, reminderList.id)
      XCTAssertEqual(decoded.title, reminderList.title)
      XCTAssertEqual(decoded.isImmutable, reminderList.isImmutable)
    }
  }
#endif

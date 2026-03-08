import XCTest
import EventKit
@testable import event

final class ReminderListTests: XCTestCase {

    func testReminderListInitialization() {
        let store = EKEventStore()
        let ekCalendar = EKCalendar(for: .reminder, eventStore: store)
        ekCalendar.title = "My List"

        let reminderList = ReminderList(from: ekCalendar)

        XCTAssertEqual(reminderList.title, "My List")
        XCTAssertFalse(reminderList.id.isEmpty)
    }

    func testReminderListImmutable() {
        let store = EKEventStore()
        let ekCalendar = EKCalendar(for: .reminder, eventStore: store)
        ekCalendar.title = "Immutable List"

        let reminderList = ReminderList(from: ekCalendar)

        XCTAssertEqual(reminderList.isImmutable, ekCalendar.isImmutable)
    }

    func testReminderListCodable() throws {
        let store = EKEventStore()
        let ekCalendar = EKCalendar(for: .reminder, eventStore: store)
        ekCalendar.title = "Test List"

        let reminderList = ReminderList(from: ekCalendar)

        let encoder = JSONEncoder()
        let data = try encoder.encode(reminderList)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ReminderList.self, from: data)

        XCTAssertEqual(decoded.id, reminderList.id)
        XCTAssertEqual(decoded.title, reminderList.title)
        XCTAssertEqual(decoded.isImmutable, reminderList.isImmutable)
    }
}

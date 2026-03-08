import XCTest
import EventKit
@testable import event

final class ReminderTests: XCTestCase {

    func testReminderInitialization() {
        let store = EKEventStore()

        let ekReminder = EKReminder(eventStore: store)
        ekReminder.title = "Buy Milk"
        ekReminder.isCompleted = true
        ekReminder.notes = "2% fat"
        ekReminder.priority = 1

        let reminder = Reminder(from: ekReminder)

        XCTAssertEqual(reminder.title, "Buy Milk")
        XCTAssertEqual(reminder.isCompleted, true)
        XCTAssertEqual(reminder.notes, "2% fat")
        XCTAssertEqual(reminder.priority, 1)
    }

    func testReminderWithNoNotesAndPriority() {
        let store = EKEventStore()
        let ekReminder = EKReminder(eventStore: store)
        ekReminder.title = "Simple Task"
        ekReminder.priority = 0 // No priority

        let reminder = Reminder(from: ekReminder)

        XCTAssertEqual(reminder.title, "Simple Task")
        XCTAssertEqual(reminder.priority, 0)
        XCTAssertNil(reminder.notes)
    }
}

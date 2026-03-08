import XCTest
import EventKit
@testable import event

final class FormatterTests: XCTestCase {

    // MARK: - MarkdownFormatter Tests

    func testMarkdownFormatterReminder() {
        let formatter = MarkdownFormatter()
        let store = EKEventStore()
        let ekReminder = EKReminder(eventStore: store)
        ekReminder.title = "Buy Milk"
        ekReminder.isCompleted = true
        ekReminder.priority = 1

        let reminder = Reminder(from: ekReminder)
        let md = formatter.format(reminder)

        XCTAssertTrue(md.contains("### Reminder: Buy Milk"))
        XCTAssertTrue(md.contains("**Status:** [x] Completed"))
        XCTAssertTrue(md.contains("**Priority:** High (!!!)"))
    }
}

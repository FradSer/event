#if canImport(EventKit)
  import EventKit
  import EventModels
  import XCTest

  @testable import event

  final class FormatterTests: XCTestCase {

    private let store = EKEventStore()

    func testMarkdownFormatterReminder() {
      let formatter = MarkdownFormatter()
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
#endif

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

    func testMarkdownFormatterEventCalendars() {
      let formatter = MarkdownFormatter()
      let calendars = [
        EventCalendar(
          id: "A970BF82-E7ED-4B6B-B367-6CAC551C8D53",
          title: "Work",
          source: "iCloud",
          sourceType: "calDAV",
          allowsContentModifications: true,
          isImmutable: false,
          color: "#FFCC00"
        ),
        EventCalendar(
          id: "D0E6BF30-3DD6-4A46-8E79-E02825C4EEB7",
          title: "Holidays",
          source: "iCloud",
          sourceType: "calDAV",
          allowsContentModifications: false,
          isImmutable: false
        ),
      ]

      let md = formatter.format(calendars)

      XCTAssertTrue(md.contains("### Calendars"))
      XCTAssertTrue(md.contains("- **Work**"))
      XCTAssertTrue(md.contains("  - Source: iCloud"))
      XCTAssertTrue(md.contains("  - Read-only"))
      XCTAssertTrue(md.contains("  - ID: `A970BF82-E7ED-4B6B-B367-6CAC551C8D53`"))
    }
  }
#endif

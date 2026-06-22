#if canImport(EventKit)
  import EventKit
  import EventModels
  import XCTest

  @testable import event

  final class CalendarEventTests: XCTestCase {

    private let store = EKEventStore()
    private let utc = TimeZone(identifier: "UTC")!

    func testCalendarEventInitialization() {
      let ekEvent = EKEvent(eventStore: store)
      ekEvent.title = "Meeting"

      let event = CalendarEvent(from: ekEvent, preferredTimeZone: utc)

      XCTAssertEqual(event.title, "Meeting")
      XCTAssertEqual(event.calendar, "Unknown")
      XCTAssertFalse(event.isAllDay)
      XCTAssertNil(event.location)
    }

    func testCalendarEventFallbackValues() {
      let ekEvent = EKEvent(eventStore: store)
      ekEvent.title = "Holiday"

      let event = CalendarEvent(from: ekEvent, preferredTimeZone: utc)

      XCTAssertEqual(event.title, "Holiday")
      XCTAssertEqual(event.calendar, "Unknown")
    }
  }
#endif

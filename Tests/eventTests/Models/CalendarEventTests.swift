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

    func testCalendarEventUsesEventTimezoneForTimedDatesByDefault() throws {
      let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
      let ekEvent = EKEvent(eventStore: store)
      ekEvent.title = "New York meeting"
      ekEvent.timeZone = newYork
      ekEvent.startDate = try XCTUnwrap(
        ISO8601DateFormatter().date(from: "2026-03-10T19:00:00Z"))
      ekEvent.endDate = try XCTUnwrap(
        ISO8601DateFormatter().date(from: "2026-03-10T20:00:00Z"))

      let event = CalendarEvent(from: ekEvent)

      XCTAssertEqual(event.startDate, "2026-03-10 15:00:00")
      XCTAssertEqual(event.endDate, "2026-03-10 16:00:00")
      XCTAssertEqual(event.timeZone, "America/New_York")
    }
  }
#endif

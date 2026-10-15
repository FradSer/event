#if canImport(EventKit)
  import EventKit
  import EventModels
  import XCTest

  @testable import event

  final class EventCalendarTests: XCTestCase {

    private let store = EKEventStore()

    func testEventCalendarMapsEventKitCalendar() {
      let ekCalendar = EKCalendar(for: .event, eventStore: store)
      ekCalendar.title = "Work"

      let calendar = EventCalendar(from: ekCalendar)

      XCTAssertEqual(calendar.title, "Work")
      XCTAssertEqual(calendar.id, ekCalendar.calendarIdentifier)
      XCTAssertEqual(calendar.allowsContentModifications, ekCalendar.allowsContentModifications)
      XCTAssertEqual(calendar.isImmutable, ekCalendar.isImmutable)
    }

    func testEventCalendarOmitsUnknownFieldsFromJSON() throws {
      // The sync backends cannot describe a calendar catalog, so they leave
      // the EventKit-only fields empty. Encoding must not invent values for
      // them, or a caller cannot tell "unknown" from "read-only".
      let calendar = EventCalendar(id: "Work", title: "Work")

      let data = try JSONEncoder().encode(calendar)
      let decoded = try JSONDecoder().decode(EventCalendar.self, from: data)

      XCTAssertEqual(decoded.id, "Work")
      XCTAssertEqual(decoded.title, "Work")
      XCTAssertNil(decoded.source)
      XCTAssertNil(decoded.sourceType)
      XCTAssertNil(decoded.allowsContentModifications)
      XCTAssertNil(decoded.isImmutable)
      XCTAssertNil(decoded.color)
    }

    func testEventCalendarRoundTripsEventKitFields() throws {
      let calendar = EventCalendar(
        id: "A970BF82-E7ED-4B6B-B367-6CAC551C8D53",
        title: "Work",
        source: "iCloud",
        sourceType: "calDAV",
        allowsContentModifications: true,
        isImmutable: false,
        color: "#FFCC00"
      )

      let data = try JSONEncoder().encode(calendar)
      let decoded = try JSONDecoder().decode(EventCalendar.self, from: data)

      XCTAssertEqual(decoded.source, "iCloud")
      XCTAssertEqual(decoded.sourceType, "calDAV")
      XCTAssertEqual(decoded.allowsContentModifications, true)
      XCTAssertEqual(decoded.isImmutable, false)
      XCTAssertEqual(decoded.color, "#FFCC00")
    }
  }
#endif

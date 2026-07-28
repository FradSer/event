#if canImport(EventKit)
  import EventModels
  import XCTest

  @testable import event

  final class CalendarDateInputResolverTests: XCTestCase {
    func testResolveAcceptsAllDayInputsForExistingAllDayEvent() throws {
      let start = try Date.validated(dateString: "2026-04-01")
      let end = try Date.validated(dateString: "2026-04-02")

      let resolution = try CalendarDateInputResolver.resolve(
        currentIsAllDay: true,
        currentStart: start,
        currentEnd: end,
        startInput: "2026-04-10",
        endInput: "2026-04-11",
        timeZone: .current
      )

      XCTAssertTrue(resolution.isAllDay)
      XCTAssertEqual(
        DateFormatter.eventDate.string(from: resolution.start),
        "2026-04-10"
      )
      XCTAssertEqual(
        DateFormatter.eventDate.string(from: resolution.end),
        "2026-04-11"
      )
    }

    func testResolveRejectsMixedAllDayAndTimedFormats() throws {
      let start = try Date.validated(dateString: "2026-04-01")
      let end = try Date.validated(dateString: "2026-04-02")

      XCTAssertThrowsError(
        try CalendarDateInputResolver.resolve(
          currentIsAllDay: true,
          currentStart: start,
          currentEnd: end,
          startInput: "2026-04-10",
          endInput: "2026-04-10 09:30:00",
          timeZone: .current
        )
      ) { error in
        guard case EventCLIError.invalidInput = error else {
          XCTFail("Expected invalidInput error, got: \(error)")
          return
        }
      }
    }

    func testResolveParsesTimedInputInProvidedTimeZone() throws {
      let chicago = try XCTUnwrap(TimeZone(identifier: "America/Chicago"))
      let newYork = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
      let currentStart = try Date.validated(
        dateTimeString: "2026-08-21 09:00:00", timeZone: chicago)
      let currentEnd = try Date.validated(
        dateTimeString: "2026-08-21 10:00:00", timeZone: chicago)

      let resolution = try CalendarDateInputResolver.resolve(
        currentIsAllDay: false,
        currentStart: currentStart,
        currentEnd: currentEnd,
        startInput: "2026-08-21 11:00:00",
        endInput: "2026-08-21 12:00:00",
        timeZone: newYork
      )

      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
      formatter.locale = Locale(identifier: "en_US_POSIX")
      formatter.timeZone = chicago

      XCTAssertEqual(formatter.string(from: resolution.start), "2026-08-21 10:00:00")
      XCTAssertEqual(formatter.string(from: resolution.end), "2026-08-21 11:00:00")
    }
  }
#endif

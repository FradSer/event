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
      endInput: "2026-04-11"
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
        endInput: "2026-04-10 09:30:00"
      )
    ) { error in
      guard case EventCLIError.invalidInput = error else {
        XCTFail("Expected invalidInput error, got: \(error)")
        return
      }
    }
  }
}

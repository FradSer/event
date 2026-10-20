#if canImport(EventKit)
  import EventKit
  import EventModels
  import XCTest

  @testable import event

  final class CalendarServiceAvailabilityTests: XCTestCase {
    func testAvailabilityWriteUsesValueSupportedByCalendar() throws {
      let value = try CalendarService.availabilityValueForWrite(
        .busy,
        supportedAvailabilities: .busy,
        skipUnsupportedAvailability: true,
        unsupportedMessage: "unsupported"
      )

      XCTAssertEqual(value, .busy)
    }

    func testSyncSkipsAvailabilityThatCalendarDoesNotSupport() throws {
      let value = try CalendarService.availabilityValueForWrite(
        .busy,
        supportedAvailabilities: .free,
        skipUnsupportedAvailability: true,
        unsupportedMessage: "unsupported"
      )

      XCTAssertNil(value)
    }

    func testDirectWriteStillRejectsUnsupportedAvailability() {
      XCTAssertThrowsError(
        try CalendarService.availabilityValueForWrite(
          .busy,
          supportedAvailabilities: .free,
          skipUnsupportedAvailability: false,
          unsupportedMessage: "unsupported"
        )
      ) { error in
        guard case EventCLIError.invalidInput("unsupported") = error else {
          XCTFail("Expected the existing unsupported-availability error, got: \(error)")
          return
        }
      }
    }
  }
#endif

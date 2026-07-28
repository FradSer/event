import EventModels
import XCTest

final class TimeZoneValidatorTests: XCTestCase {
  func testResolveReturnsRequestedIanaTimeZone() throws {
    let timeZone = try TimeZoneValidator.resolve(identifier: "America/New_York")

    XCTAssertEqual(timeZone?.identifier, "America/New_York")
  }

  func testResolveRejectsUnknownTimeZone() {
    XCTAssertThrowsError(try TimeZoneValidator.resolve(identifier: "Not/A_Timezone")) { error in
      guard case EventCLIError.invalidInput(let message) = error else {
        XCTFail("Expected invalidInput error, got: \(error)")
        return
      }
      XCTAssertEqual(message, "Unknown IANA timezone 'Not/A_Timezone'")
    }
  }
}

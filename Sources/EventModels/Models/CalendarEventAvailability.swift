import Foundation

/// Availability values that can be written to a calendar event.
public enum CalendarEventAvailability: String, Codable, CaseIterable, Sendable {
  case busy
  case free
  case tentative
  case unavailable
}

import Foundation

/// Resolves IANA timezone identifiers supplied through the CLI.
public enum TimeZoneValidator {
  public static func resolve(identifier: String?) throws -> TimeZone? {
    guard let identifier else {
      return nil
    }
    guard let timeZone = TimeZone(identifier: identifier) else {
      throw EventCLIError.invalidInput("Unknown IANA timezone '\(identifier)'")
    }
    return timeZone
  }
}

import Foundation

// MARK: - Error Handling

public enum EventCLIError: LocalizedError, Sendable {
  case permissionDenied(String)
  case notFound(String)
  case invalidInput(String)
  case eventKitError(String)
  case invalidDate(String)
  case invalidDateRange(String)
  case dateOutOfRange(String)
  case unknown(String)

  public var errorDescription: String? {
    switch self {
    case .permissionDenied(let message):
      return "Permission denied: \(message)"
    case .notFound(let message):
      return "Not found: \(message)"
    case .invalidInput(let message):
      return "Invalid input: \(message)"
    case .eventKitError(let message):
      return "EventKit error: \(message)"
    case .invalidDate(let message):
      return "Invalid date: \(message)"
    case .invalidDateRange(let message):
      return "Invalid date range: \(message)"
    case .dateOutOfRange(let message):
      return "Date out of range: \(message)"
    case .unknown(let message):
      return "Error: \(message)"
    }
  }
}

/// Formats error messages for CLI output
public enum ErrorFormatter {
  public static func format(_ error: Error) -> String {
    if let cliError = error as? EventCLIError {
      return cliError.errorDescription ?? "Unknown error"
    }
    return "Error: \(error.localizedDescription)"
  }
}

import Foundation

// MARK: - Error Handling

enum EventCLIError: LocalizedError {
    case permissionDenied(String)
    case notFound(String)
    case invalidInput(String)
    case eventKitError(String)
    case invalidDate(String)
    case invalidDateRange(String)
    case dateOutOfRange(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case let .permissionDenied(message):
            return "Permission denied: \(message)"
        case let .notFound(message):
            return "Not found: \(message)"
        case let .invalidInput(message):
            return "Invalid input: \(message)"
        case let .eventKitError(message):
            return "EventKit error: \(message)"
        case let .invalidDate(message):
            return "Invalid date: \(message)"
        case let .invalidDateRange(message):
            return "Invalid date range: \(message)"
        case let .dateOutOfRange(message):
            return "Date out of range: \(message)"
        case let .unknown(message):
            return "Error: \(message)"
        }
    }
}

/// Formats error messages for CLI output
enum ErrorFormatter {
    static func format(_ error: Error) -> String {
        if let cliError = error as? EventCLIError {
            return cliError.errorDescription ?? "Unknown error"
        }
        return "Error: \(error.localizedDescription)"
    }
}

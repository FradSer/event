import Foundation

// MARK: - Date Formatter Extensions

extension DateFormatter {
    /// Standard date-time formatter: yyyy-MM-dd HH:mm:ss
    public static let eventDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = .current
        return formatter
    }()

    /// Date-only formatter: yyyy-MM-dd
    public static let eventDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter
    }()

    /// ISO 8601 formatter for JSON output
    public static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

// MARK: - Date Parsing Utilities

extension Date {
    /// Parse date from string in format "yyyy-MM-dd HH:mm:ss" with validation
    public static func validated(dateTimeString: String) throws -> Date {
        return try DateValidator.validateDateTime(dateTimeString)
    }

    /// Parse date from string in format "yyyy-MM-dd" with validation
    public static func validated(dateString: String) throws -> Date {
        return try DateValidator.validateDate(dateString)
    }

    /// Check if string is in all-day format (yyyy-MM-dd)
    public static func isAllDayFormat(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespaces)

        guard trimmed.count == 10 && !trimmed.contains(":") else {
            return false
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let date = formatter.date(from: trimmed) else {
            return false
        }

        return formatter.string(from: date) == trimmed
    }

    /// Parse date from string in format "yyyy-MM-dd HH:mm:ss"
    @available(*, deprecated, message: "Use validated(dateTimeString:) instead")
    public static func from(dateTimeString: String) -> Date? {
        return DateFormatter.eventDateTime.date(from: dateTimeString)
    }

    /// Parse date from string in format "yyyy-MM-dd"
    @available(*, deprecated, message: "Use validated(dateString:) instead")
    public static func from(dateString: String) -> Date? {
        return DateFormatter.eventDate.date(from: dateString)
    }
}

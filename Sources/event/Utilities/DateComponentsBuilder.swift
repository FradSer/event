import Foundation

/// Builds DateComponents with proper timezone handling
enum DateComponentsBuilder {
    /// Build DateComponents with timezone for timed events
    /// Includes year, month, day, hour, minute, and timeZone components
    static func build(from date: Date, timeZone: TimeZone = .current) -> DateComponents {
        var calendar = Calendar.current
        calendar.timeZone = timeZone

        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        components.timeZone = timeZone

        return components
    }

    /// Build DateComponents for all-day events (date only, no time)
    /// Includes only year, month, and day components
    static func buildAllDay(from date: Date, timeZone: TimeZone = .current) -> DateComponents {
        var calendar = Calendar.current
        calendar.timeZone = timeZone

        return calendar.dateComponents(
            [.year, .month, .day],
            from: date
        )
    }

    /// Convert DateComponents to Date with timezone
    static func toDate(from components: DateComponents, timeZone: TimeZone = .current) -> Date? {
        var calendar = Calendar.current
        calendar.timeZone = components.timeZone ?? timeZone

        return calendar.date(from: components)
    }
}

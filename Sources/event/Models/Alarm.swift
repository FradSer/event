import EventKit
import Foundation

// MARK: - Alarm Model

struct Alarm: Codable {
    let relativeOffset: Double?
    let absoluteDate: String?
    let locationTrigger: LocationTrigger?
    let alarmType: String?

    init(from ekAlarm: EKAlarm, preferredTimeZone: TimeZone = .current) {
        // Check if this is a location-based alarm
        if let locationTrigger = LocationTrigger(from: ekAlarm) {
            relativeOffset = nil
            absoluteDate = nil
            self.locationTrigger = locationTrigger
        } else if let absoluteDate = ekAlarm.absoluteDate {
            // Absolute date alarm
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = preferredTimeZone
            relativeOffset = nil
            self.absoluteDate = formatter.string(from: absoluteDate)
            locationTrigger = nil
        } else {
            // Relative offset alarm
            relativeOffset = ekAlarm.relativeOffset
            absoluteDate = nil
            locationTrigger = nil
        }

        // Set alarm type
        switch ekAlarm.type {
        case .display:
            alarmType = "display"
        case .audio:
            alarmType = "audio"
        case .procedure:
            alarmType = "procedure"
        case .email:
            alarmType = "email"
        @unknown default:
            alarmType = nil
        }
    }
}

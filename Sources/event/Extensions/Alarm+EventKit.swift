import EventKit
import EventModels
import Foundation

extension Alarm {
    init(from ekAlarm: EKAlarm, preferredTimeZone: TimeZone = .current) {
        let alarmType: String?
        switch ekAlarm.type {
        case .display: alarmType = "display"
        case .audio: alarmType = "audio"
        case .procedure: alarmType = "procedure"
        case .email: alarmType = "email"
        @unknown default: alarmType = nil
        }

        if let locationTrigger = LocationTrigger(from: ekAlarm) {
            self.init(
                relativeOffset: nil,
                absoluteDate: nil,
                locationTrigger: locationTrigger,
                alarmType: alarmType
            )
        } else if let absoluteDate = ekAlarm.absoluteDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            formatter.timeZone = preferredTimeZone
            self.init(
                relativeOffset: nil,
                absoluteDate: formatter.string(from: absoluteDate),
                locationTrigger: nil,
                alarmType: alarmType
            )
        } else {
            self.init(
                relativeOffset: ekAlarm.relativeOffset,
                absoluteDate: nil,
                locationTrigger: nil,
                alarmType: alarmType
            )
        }
    }
}

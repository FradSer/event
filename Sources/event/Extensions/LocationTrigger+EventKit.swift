import CoreLocation
import EventKit
import EventModels
import Foundation

extension LocationTrigger {
    init?(from ekAlarm: EKAlarm) {
        guard let structuredLocation = ekAlarm.structuredLocation,
            let geoLocation = structuredLocation.geoLocation
        else {
            return nil
        }

        self.init(
            title: structuredLocation.title ?? "Location",
            latitude: geoLocation.coordinate.latitude,
            longitude: geoLocation.coordinate.longitude,
            radius: structuredLocation.radius > 0 ? structuredLocation.radius : 100,
            proximity: {
                switch ekAlarm.proximity {
                case .enter: return "enter"
                case .leave: return "leave"
                default: return "none"
                }
            }()
        )
    }

    func toEKStructuredLocation() -> (EKStructuredLocation, EKAlarmProximity) {
        let structuredLocation = EKStructuredLocation(title: title)
        structuredLocation.geoLocation = CLLocation(latitude: latitude, longitude: longitude)
        structuredLocation.radius = radius > 0 ? radius : 100

        let proximityValue: EKAlarmProximity
        switch proximity.lowercased() {
        case "leave", "depart", "exit":
            proximityValue = .leave
        default:
            proximityValue = .enter
        }

        return (structuredLocation, proximityValue)
    }
}

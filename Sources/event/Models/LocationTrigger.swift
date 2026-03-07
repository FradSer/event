import CoreLocation
import EventKit
import Foundation

// MARK: - Location Trigger Model

struct LocationTrigger: Codable {
    let title: String
    let latitude: Double
    let longitude: Double
    let radius: Double
    let proximity: String // "enter" or "leave"

    init?(from ekAlarm: EKAlarm) {
        guard let structuredLocation = ekAlarm.structuredLocation,
              let geoLocation = structuredLocation.geoLocation
        else {
            return nil
        }

        title = structuredLocation.title ?? "Location"
        latitude = geoLocation.coordinate.latitude
        longitude = geoLocation.coordinate.longitude
        radius = structuredLocation.radius > 0 ? structuredLocation.radius : 100

        switch ekAlarm.proximity {
        case .enter:
            proximity = "enter"
        case .leave:
            proximity = "leave"
        default:
            proximity = "none"
        }
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

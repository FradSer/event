import CoreLocation
import EventKit
import Foundation

// MARK: - Location Trigger Model

struct LocationTrigger: Codable {
  enum Proximity: String, Codable {
    case enter, leave
  }

  static let defaultRadius: Double = 100

  let title: String
  let latitude: Double
  let longitude: Double
  let radius: Double
  let proximity: Proximity

  init(
    title: String,
    latitude: Double,
    longitude: Double,
    radius: Double,
    proximity: Proximity
  ) {
    self.title = title
    self.latitude = latitude
    self.longitude = longitude
    self.radius = Self.sanitizedRadius(radius)
    self.proximity = proximity
  }

  init?(from ekAlarm: EKAlarm) {
    guard let structuredLocation = ekAlarm.structuredLocation,
      let geoLocation = structuredLocation.geoLocation
    else {
      return nil
    }

    let mappedProximity: Proximity
    switch ekAlarm.proximity {
    case .enter:
      mappedProximity = .enter
    case .leave:
      mappedProximity = .leave
    default:
      // `.none` means the alarm has no proximity trigger — not a location trigger we represent.
      return nil
    }

    title = structuredLocation.title ?? "Location"
    latitude = geoLocation.coordinate.latitude
    longitude = geoLocation.coordinate.longitude
    radius = Self.sanitizedRadius(structuredLocation.radius)
    proximity = mappedProximity
  }

  /// Build an `EKAlarm` carrying this trigger's structured location and proximity.
  func toEKAlarm() -> EKAlarm {
    let structuredLocation = EKStructuredLocation(title: title)
    structuredLocation.geoLocation = CLLocation(latitude: latitude, longitude: longitude)
    structuredLocation.radius = radius

    let alarm = EKAlarm()
    alarm.structuredLocation = structuredLocation
    alarm.proximity = (proximity == .leave) ? .leave : .enter
    return alarm
  }

  private static func sanitizedRadius(_ r: Double) -> Double {
    r > 0 ? r : defaultRadius
  }
}

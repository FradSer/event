import CoreLocation
import EventKit
import Foundation

// MARK: - Location Trigger Model

struct LocationTrigger: Codable {
  let title: String
  let latitude: Double
  let longitude: Double
  let radius: Double
  let proximity: String  // "enter" or "leave"

  init(title: String, latitude: Double, longitude: Double, radius: Double, proximity: String) {
    self.title = title
    self.latitude = latitude
    self.longitude = longitude
    self.radius = radius
    self.proximity = proximity
  }

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

  /// Build a `LocationTrigger` from CLI-supplied options.
  ///
  /// - Returns: `nil` when none of the location-related options are supplied.
  /// - Throws: `EventCLIError.invalidInput` when the options are partially supplied
  ///   (the trigger requires `name`, `latitude`, and `longitude` together), or when
  ///   `proximity` is not `"enter"` or `"leave"`.
  static func fromCLI(
    name: String?,
    latitude: Double?,
    longitude: Double?,
    radius: Double?,
    proximity: String?
  ) throws -> LocationTrigger? {
    let anySet =
      name != nil || latitude != nil || longitude != nil || radius != nil || proximity != nil
    if !anySet { return nil }

    guard let name = name, let lat = latitude, let lon = longitude else {
      throw EventCLIError.invalidInput(
        "--location, --latitude and --longitude must be provided together."
      )
    }

    let normalizedProximity = (proximity ?? "enter").lowercased()
    switch normalizedProximity {
    case "enter", "leave":
      break
    default:
      throw EventCLIError.invalidInput(
        "--proximity must be 'enter' or 'leave' (got '\(normalizedProximity)')."
      )
    }

    let resolvedRadius = (radius ?? 100) > 0 ? (radius ?? 100) : 100

    return LocationTrigger(
      title: name,
      latitude: lat,
      longitude: lon,
      radius: resolvedRadius,
      proximity: normalizedProximity
    )
  }
}

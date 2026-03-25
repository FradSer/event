import Foundation

// MARK: - Location Trigger Model

public struct LocationTrigger: Codable, Sendable {
    public let title: String
    public let latitude: Double
    public let longitude: Double
    public let radius: Double
    public let proximity: String  // "enter" or "leave"

    public init(
        title: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        proximity: String
    ) {
        self.title = title
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.proximity = proximity
    }
}

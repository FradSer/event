import Foundation

// MARK: - Alarm Model

public struct Alarm: Codable, Sendable {
    public let relativeOffset: Double?
    public let absoluteDate: String?
    public let locationTrigger: LocationTrigger?
    public let alarmType: String?

    public init(
        relativeOffset: Double?,
        absoluteDate: String?,
        locationTrigger: LocationTrigger?,
        alarmType: String?
    ) {
        self.relativeOffset = relativeOffset
        self.absoluteDate = absoluteDate
        self.locationTrigger = locationTrigger
        self.alarmType = alarmType
    }
}

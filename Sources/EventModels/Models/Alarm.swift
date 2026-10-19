import Foundation

// MARK: - Alarm Model

public struct Alarm: Codable, Sendable, Equatable {
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

  public static func relative(minutesBeforeStart minutes: Int) -> Alarm {
    Alarm(
      relativeOffset: -Double(minutes) * 60,
      absoluteDate: nil,
      locationTrigger: nil,
      alarmType: nil
    )
  }

  public static func relativeAlarms(minutesBeforeStart minutes: [Int]?) -> [Alarm]? {
    guard let minutes else { return nil }
    var offsets = Set<Double>()
    return minutes.compactMap { value in
      let alarm = relative(minutesBeforeStart: value)
      guard let offset = alarm.relativeOffset, offsets.insert(offset).inserted else {
        return nil
      }
      return alarm
    }
  }

  public static func updated(
    existing: [Alarm]?,
    replacing minutes: [Int]?,
    adding additionalMinutes: [Int]?
  ) -> [Alarm]? {
    guard minutes != nil || additionalMinutes != nil else { return existing }
    var alarms =
      minutes.map { relativeAlarms(minutesBeforeStart: $0) ?? [] }
      ?? existing
      ?? []
    var offsets = Set(alarms.compactMap(\.relativeOffset))
    for value in additionalMinutes ?? [] {
      let alarm = relative(minutesBeforeStart: value)
      guard let offset = alarm.relativeOffset, offsets.insert(offset).inserted else {
        continue
      }
      alarms.append(alarm)
    }
    return alarms
  }
}

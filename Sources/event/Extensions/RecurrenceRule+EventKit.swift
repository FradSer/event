#if canImport(EventKit)

  import EventKit
  import EventModels
  import Foundation

  extension RecurrenceRule {
    init(from ekRule: EKRecurrenceRule) {
      let frequency: String
      switch ekRule.frequency {
      case .daily: frequency = "daily"
      case .weekly: frequency = "weekly"
      case .monthly: frequency = "monthly"
      case .yearly: frequency = "yearly"
      @unknown default: frequency = "unknown"
      }

      let daysOfWeek = ekRule.daysOfTheWeek?.compactMap { dayOfWeek -> String? in
        let index = dayOfWeek.dayOfTheWeek.rawValue
        guard index >= 0, index < Self.weekdayNames.count else { return nil }
        return Self.weekdayNames[index]
      }

      let endDate: String?
      if let endDateValue = ekRule.recurrenceEnd?.endDate {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        endDate = formatter.string(from: endDateValue)
      } else {
        endDate = nil
      }

      let occurrenceCount = ekRule.recurrenceEnd?.occurrenceCount ?? 0

      self.init(
        frequency: frequency,
        interval: ekRule.interval,
        daysOfWeek: daysOfWeek,
        daysOfMonth: ekRule.daysOfTheMonth?.map { $0.intValue },
        monthsOfYear: ekRule.monthsOfTheYear?.map { $0.intValue },
        weeksOfYear: ekRule.weeksOfTheYear?.map { $0.intValue },
        daysOfYear: ekRule.daysOfTheYear?.map { $0.intValue },
        setPositions: ekRule.setPositions?.map { $0.intValue },
        endDate: endDate,
        occurrenceCount: occurrenceCount > 0 ? occurrenceCount : nil
      )
    }

    /// Inverse of `init(from:)`. Throws `EventCLIError.invalidInput` for a frequency
    /// EventKit reminders cannot express or an unknown weekday name.
    func toEKRecurrenceRule() throws -> EKRecurrenceRule {
      let ekFrequency: EKRecurrenceFrequency
      switch frequency {
      case "daily": ekFrequency = .daily
      case "weekly": ekFrequency = .weekly
      case "monthly": ekFrequency = .monthly
      case "yearly": ekFrequency = .yearly
      default:
        throw EventCLIError.invalidInput(
          "Recurrence frequency must be daily, weekly, monthly or yearly (got '\(frequency)').")
      }

      let days = try daysOfWeek?.map { name -> EKRecurrenceDayOfWeek in
        guard let index = Self.weekdayNames.firstIndex(of: name), index > 0,
          let weekday = EKWeekday(rawValue: index)
        else {
          throw EventCLIError.invalidInput("Unknown weekday '\(name)' in recurrence rule.")
        }
        return EKRecurrenceDayOfWeek(weekday)
      }

      var end: EKRecurrenceEnd?
      if let endDate {
        let day = try Date.validated(dateString: endDate)
        // Inclusive: an occurrence falling on the end date itself still counts.
        let endOfDay = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: day)
        end = EKRecurrenceEnd(end: endOfDay ?? day)
      } else if let occurrenceCount {
        end = EKRecurrenceEnd(occurrenceCount: occurrenceCount)
      }

      func numbers(_ values: [Int]?) -> [NSNumber]? {
        guard let values, !values.isEmpty else { return nil }
        return values.map { NSNumber(value: $0) }
      }

      return EKRecurrenceRule(
        recurrenceWith: ekFrequency,
        interval: interval,
        daysOfTheWeek: days.flatMap { $0.isEmpty ? nil : $0 },
        daysOfTheMonth: numbers(daysOfMonth),
        monthsOfTheYear: numbers(monthsOfYear),
        weeksOfTheYear: numbers(weeksOfYear),
        daysOfTheYear: numbers(daysOfYear),
        setPositions: numbers(setPositions),
        end: end
      )
    }
  }

#endif

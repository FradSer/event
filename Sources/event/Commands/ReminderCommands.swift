import ArgumentParser
import EventModels
import Foundation

// MARK: - Reminder Commands

struct ReminderCommands: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "reminders",
    abstract: "Manage Apple Reminders (tasks, lists, subtasks)",
    subcommands: [List.self, Create.self, Update.self, Delete.self, Search.self, ListCommands.self]
  )

  /// Shared `--location/--latitude/--longitude/--radius/--proximity` flags for the
  /// commands that accept a location-based alarm.
  struct LocationOptions: ParsableArguments {
    @Option(name: .long, help: "Location trigger name (e.g. \"Home\")")
    var location: String?

    @Option(name: .long, help: "Location latitude (decimal degrees)")
    var latitude: Double?

    @Option(name: .long, help: "Location longitude (decimal degrees)")
    var longitude: Double?

    @Option(name: .long, help: "Geofence radius in meters (default 100)")
    var radius: Double?

    @Option(name: .long, help: "Trigger on: enter | leave (default enter)")
    var proximity: String?

    /// `true` when any of the location-related flags were supplied on the command line.
    var isPresent: Bool {
      location != nil || latitude != nil || longitude != nil || radius != nil || proximity != nil
    }

    /// Parse the supplied flags into a `LocationTrigger`, returning `nil` when none were
    /// supplied. Throws `EventCLIError.invalidInput` on partial input, out-of-range
    /// coordinates, or an unsupported `--proximity` value.
    func resolveTrigger() throws -> LocationTrigger? {
      guard isPresent else { return nil }
      guard let name = location, let lat = latitude, let lon = longitude else {
        throw EventCLIError.invalidInput(
          "Location requires --location, --latitude and --longitude together "
            + "(--radius and --proximity are optional)."
        )
      }

      guard (-90.0...90.0).contains(lat) else {
        throw EventCLIError.invalidInput(
          "--latitude must be between -90 and 90 (got \(lat))."
        )
      }
      guard (-180.0...180.0).contains(lon) else {
        throw EventCLIError.invalidInput(
          "--longitude must be between -180 and 180 (got \(lon))."
        )
      }

      let proximityValue: LocationTrigger.Proximity
      if let raw = proximity {
        guard let parsed = LocationTrigger.Proximity(rawValue: raw.lowercased()) else {
          throw EventCLIError.invalidInput(
            "--proximity must be 'enter' or 'leave' (got '\(raw)')."
          )
        }
        proximityValue = parsed
      } else {
        proximityValue = .enter
      }

      return LocationTrigger(
        title: name,
        latitude: lat,
        longitude: lon,
        radius: radius ?? LocationTrigger.defaultRadius,
        proximity: proximityValue
      )
    }
  }

  /// Shared `--recurrence*` flags for the commands that accept a repeat rule.
  struct RecurrenceOptions: ParsableArguments {
    @Option(name: .long, help: "Repeat frequency: daily | weekly | monthly | yearly")
    var recurrence: String?

    @Option(name: .long, help: "Repeat every N periods (default 1)")
    var recurrenceInterval: Int?

    @Option(name: .long, help: "Last day of the series (yyyy-MM-dd, inclusive)")
    var recurrenceEnd: String?

    @Option(name: .long, help: "Stop after N occurrences (instead of --recurrence-end)")
    var recurrenceCount: Int?

    @Option(
      name: .long,
      help: "Comma-separated weekdays for weekly/monthly/yearly rules (e.g. \"mon,wed\" or \"2,4\")"
    )
    var recurrenceDays: String?

    @Option(name: .long, help: "Comma-separated days of the month (1-31) for monthly rules")
    var recurrenceDaysOfMonth: String?

    @Option(name: .long, help: "Comma-separated months (1-12) for yearly rules")
    var recurrenceMonths: String?

    /// `true` when any of the recurrence flags were supplied on the command line.
    var isPresent: Bool {
      recurrence != nil || recurrenceInterval != nil || recurrenceEnd != nil
        || recurrenceCount != nil || recurrenceDays != nil || recurrenceDaysOfMonth != nil
        || recurrenceMonths != nil
    }

    static let frequencies = ["daily", "weekly", "monthly", "yearly"]

    /// Parse the supplied flags into a `RecurrenceRule`, returning `nil` when none were
    /// supplied. Throws `EventCLIError.invalidInput` on a missing or unknown frequency,
    /// out-of-range values, or a refinement that does not apply to the frequency.
    func resolveRule() throws -> RecurrenceRule? {
      guard isPresent else { return nil }
      guard let rawFrequency = recurrence else {
        throw EventCLIError.invalidInput(
          "Recurrence requires --recurrence <daily|weekly|monthly|yearly>; "
            + "the other --recurrence-* flags refine it."
        )
      }
      let frequency = rawFrequency.lowercased()
      guard Self.frequencies.contains(frequency) else {
        throw EventCLIError.invalidInput(
          "--recurrence must be daily, weekly, monthly or yearly (got '\(rawFrequency)')."
        )
      }

      let interval = recurrenceInterval ?? 1
      guard interval >= 1 else {
        throw EventCLIError.invalidInput(
          "--recurrence-interval must be at least 1 (got \(interval)).")
      }
      if recurrenceEnd != nil, recurrenceCount != nil {
        throw EventCLIError.invalidInput(
          "Use either --recurrence-end or --recurrence-count, not both.")
      }
      if let end = recurrenceEnd {
        _ = try Date.validated(dateString: end)
      }
      if let count = recurrenceCount, count < 1 {
        throw EventCLIError.invalidInput("--recurrence-count must be at least 1 (got \(count)).")
      }

      let daysOfWeek = try recurrenceDays.map(Self.parseWeekdays)
      if daysOfWeek != nil, frequency == "daily" {
        throw EventCLIError.invalidInput(
          "--recurrence-days applies to weekly, monthly or yearly rules, not daily.")
      }
      let daysOfMonth = try recurrenceDaysOfMonth.map {
        try Self.parseIntegers($0, flag: "--recurrence-days-of-month", range: 1...31)
      }
      if daysOfMonth != nil, frequency != "monthly" {
        throw EventCLIError.invalidInput(
          "--recurrence-days-of-month applies to monthly rules only.")
      }
      let monthsOfYear = try recurrenceMonths.map {
        try Self.parseIntegers($0, flag: "--recurrence-months", range: 1...12)
      }
      if monthsOfYear != nil, frequency != "yearly" {
        throw EventCLIError.invalidInput("--recurrence-months applies to yearly rules only.")
      }

      return RecurrenceRule(
        frequency: frequency,
        interval: interval,
        daysOfWeek: daysOfWeek,
        daysOfMonth: daysOfMonth,
        monthsOfYear: monthsOfYear,
        weeksOfYear: nil,
        daysOfYear: nil,
        setPositions: nil,
        endDate: recurrenceEnd,
        occurrenceCount: recurrenceCount
      )
    }

    /// Accepts full names, three-letter abbreviations (case-insensitive) or 1-7 (1 = Sunday).
    static func parseWeekdays(_ raw: String) throws -> [String] {
      let names = try raw.split(separator: ",").map { part -> String in
        let token = part.trimmingCharacters(in: .whitespaces).lowercased()
        if let number = Int(token) {
          guard (1...7).contains(number) else {
            throw EventCLIError.invalidInput(
              "--recurrence-days: weekday numbers run 1 (Sunday) to 7 (Saturday), got \(number).")
          }
          return RecurrenceRule.weekdayNames[number]
        }
        let match = RecurrenceRule.weekdayNames.dropFirst().first { name in
          let lower = name.lowercased()
          return lower == token || (token.count == 3 && lower.hasPrefix(token))
        }
        guard let match else {
          throw EventCLIError.invalidInput("--recurrence-days: unknown weekday '\(part)'.")
        }
        return match
      }
      guard !names.isEmpty else {
        throw EventCLIError.invalidInput("--recurrence-days needs at least one weekday.")
      }
      return names
    }

    static func parseIntegers(_ raw: String, flag: String, range: ClosedRange<Int>) throws -> [Int]
    {
      let values = try raw.split(separator: ",").map { part -> Int in
        let token = part.trimmingCharacters(in: .whitespaces)
        guard let number = Int(token), range.contains(number) else {
          throw EventCLIError.invalidInput(
            "\(flag) expects integers from \(range.lowerBound) to \(range.upperBound), got '\(token)'."
          )
        }
        return number
      }
      guard !values.isEmpty else {
        throw EventCLIError.invalidInput("\(flag) needs at least one value.")
      }
      return values
    }
  }

  struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "List reminders"
    )

    @Option(name: .shortAndLong, help: "Filter by list name")
    var list: String?

    @Flag(name: .shortAndLong, help: "Include completed reminders")
    var completed = false

    @Option(
      name: .shortAndLong,
      help: "Start of the due-date window (yyyy-MM-dd, inclusive)"
    )
    var start: String?

    @Option(
      name: .shortAndLong,
      help: "End of the due-date window (yyyy-MM-dd, exclusive)"
    )
    var end: String?

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      // `calendar list` accepts a bare start or end and fills the other side
      // with a window; here both bounds are required together so a one-sided
      // query can't silently expand to the whole store. Validate the bounds up
      // front (throwing on garbage) so a bad window surfaces a clear error
      // instead of an empty result set.
      if (start == nil) != (end == nil) {
        throw EventCLIError.invalidInput(
          "Use both --start and --end to filter reminders by due date."
        )
      }
      if let start, let end {
        let startDate = try Date.validated(dateString: start)
        let endDate = try Date.validated(dateString: end)
        // An inverted window would silently return an empty list; error up
        // front instead. Equal bounds are allowed (half-open, end-exclusive).
        try DateValidator.validateDateRange(start: startDate, end: endDate)
      }

      let backend = try await BackendFactory.makeRemindersBackend()
      let reminders = try await backend.fetchReminders(
        listName: list,
        showCompleted: completed,
        startDate: start,
        endDate: end
      )

      let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
      print(formatter.format(reminders))
    }
  }

  struct Create: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Create a new reminder"
    )

    @Option(name: .shortAndLong, help: "Reminder title")
    var title: String

    @Option(name: .shortAndLong, help: "List name")
    var list: String?

    @Option(name: .shortAndLong, help: "Due date (yyyy-MM-dd HH:mm:ss)")
    var due: String?

    @Option(name: .shortAndLong, help: "Priority (0-9)")
    var priority: Int?

    @Option(name: .shortAndLong, help: "Notes")
    var notes: String?

    @Option(name: .shortAndLong, help: "URL")
    var url: String?

    @Option(help: "Comma-separated tags")
    var tags: String?

    @Option(help: "Parent reminder title (for creating subtasks via Shortcut)")
    var parentTitle: String?

    @Option(help: "Mark as flagged (true/false)")
    var flagged: Bool?

    @OptionGroup var locationOptions: LocationOptions

    @OptionGroup var recurrenceOptions: RecurrenceOptions

    @Flag(name: .long, help: "Disable Shortcut integration")
    var noShortcuts = false

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      #if canImport(EventKit)
        let locationTrigger = try locationOptions.resolveTrigger()
        let recurrenceRule = try recurrenceOptions.resolveRule()
        let service = ReminderService()
        let reminder = try await service.createReminder(
          title: title,
          listName: list,
          notes: notes,
          url: url,
          dueDate: due,
          priority: priority,
          tags: tags,
          parentTitle: parentTitle,
          flagged: flagged,
          locationTrigger: locationTrigger,
          recurrenceRule: recurrenceRule,
          useShortcuts: !noShortcuts
        )
      #else
        let backend = try await BackendFactory.makeRemindersBackend()
        let params = CreateReminderParams(
          title: title,
          listName: list,
          notes: notes,
          url: url,
          dueDate: due,
          priority: priority ?? 0
        )
        let reminder = try await backend.createReminder(params)
        if tags != nil || parentTitle != nil || flagged != nil
          || locationOptions.isPresent || recurrenceOptions.isPresent || noShortcuts
        {
          print(
            "Note: tags, parentTitle, flagged, location triggers, recurrence, and shortcuts are "
              + "macOS-only features."
          )
        }
      #endif

      let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
      print(formatter.format(reminder))
    }
  }

  struct Update: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Update an existing reminder"
    )

    @Option(name: .shortAndLong, help: "Reminder ID")
    var id: String

    @Option(name: .shortAndLong, help: "New title")
    var title: String?

    @Option(name: .shortAndLong, help: "Mark as completed (true/false)")
    var completed: Bool?

    @Option(name: .shortAndLong, help: "New priority (0-9)")
    var priority: Int?

    @Option(name: .shortAndLong, help: "New due date (yyyy-MM-dd HH:mm:ss)")
    var due: String?

    @Flag(name: .long, help: "Remove due date")
    var clearDue = false

    @Option(name: .long, help: "New start date (yyyy-MM-dd HH:mm:ss)")
    var start: String?

    @Flag(name: .long, help: "Remove start date")
    var clearStart = false

    @Option(name: .shortAndLong, help: "New notes")
    var notes: String?

    @Option(help: "Comma-separated tags")
    var tags: String?

    @Option(name: .shortAndLong, help: "New URL")
    var url: String?

    @Option(help: "Parent reminder title (for converting to subtask)")
    var parentTitle: String?

    @Option(help: "Mark as flagged (true/false)")
    var flagged: Bool?

    @OptionGroup var locationOptions: LocationOptions

    @Flag(name: .long, help: "Remove existing location-based alarms")
    var clearLocation = false

    @OptionGroup var recurrenceOptions: RecurrenceOptions

    @Flag(name: .long, help: "Remove the repeat rule")
    var clearRecurrence = false

    @Flag(name: .long, help: "Disable Shortcut integration")
    var noShortcuts = false

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      if clearDue, due != nil {
        throw EventCLIError.invalidInput("Use either --due or --clear-due, not both.")
      }
      if clearStart, start != nil {
        throw EventCLIError.invalidInput("Use either --start or --clear-start, not both.")
      }
      // Check against raw flag presence -- not the parsed trigger -- so a partial location
      // input alongside --clear-location surfaces the more helpful mutual-exclusion error
      // rather than the "must be provided together" one.
      if clearLocation, locationOptions.isPresent {
        throw EventCLIError.invalidInput(
          "Use either --location/--latitude/--longitude or --clear-location, not both."
        )
      }
      if clearRecurrence, recurrenceOptions.isPresent {
        throw EventCLIError.invalidInput(
          "Use either --recurrence/--recurrence-* or --clear-recurrence, not both."
        )
      }

      #if canImport(EventKit)
        let locationTrigger = try locationOptions.resolveTrigger()
        let recurrenceRule = try recurrenceOptions.resolveRule()
        let service = ReminderService()
        let reminder = try await service.updateReminder(
          id: id,
          title: title,
          completed: completed,
          notes: notes,
          dueDate: due,
          clearDue: clearDue,
          startDate: start,
          clearStart: clearStart,
          priority: priority,
          tags: tags,
          url: url,
          parentTitle: parentTitle,
          flagged: flagged,
          locationTrigger: locationTrigger,
          clearLocation: clearLocation,
          recurrenceRule: recurrenceRule,
          clearRecurrence: clearRecurrence,
          useShortcuts: !noShortcuts
        )
      #else
        let backend = try await BackendFactory.makeRemindersBackend()
        let params = UpdateReminderParams(
          title: title,
          completed: completed,
          notes: notes,
          dueDate: due,
          clearDue: clearDue,
          startDate: start,
          clearStart: clearStart,
          priority: priority,
          url: url
        )
        let reminder = try await backend.updateReminder(id: id, params: params)
        if tags != nil || parentTitle != nil || flagged != nil
          || locationOptions.isPresent || clearLocation || recurrenceOptions.isPresent
          || clearRecurrence || noShortcuts
        {
          print(
            "Note: tags, parentTitle, flagged, location triggers, recurrence, and shortcuts are "
              + "macOS-only features."
          )
        }
      #endif

      let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
      print(formatter.format(reminder))
    }
  }

  struct Delete: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Delete a reminder"
    )

    @Option(name: .shortAndLong, help: "Reminder ID")
    var id: String

    func run() async throws {
      let backend = try await BackendFactory.makeRemindersBackend()
      try await backend.deleteReminder(id: id)
      print("Reminder deleted successfully")
    }
  }

  struct Search: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Search reminders by keyword in title and notes"
    )

    @Option(name: .shortAndLong, help: "Search keyword")
    var keyword: String

    @Option(name: .shortAndLong, help: "Filter by list name")
    var list: String?

    @Flag(name: .shortAndLong, help: "Include completed reminders")
    var completed = false

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      #if canImport(EventKit)
        let service = ReminderService()
        let reminders = try await service.searchReminders(
          keyword: keyword,
          listName: list,
          showCompleted: completed
        )
      #else
        let backend = try await BackendFactory.makeRemindersBackend()
        let all = try await backend.fetchReminders(
          listName: list, showCompleted: completed, startDate: nil, endDate: nil)
        let lowercased = keyword.lowercased()
        let reminders = all.filter { reminder in
          reminder.title.lowercased().contains(lowercased)
            || (reminder.notes?.lowercased().contains(lowercased) ?? false)
        }
      #endif

      let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
      print(formatter.format(reminders))
    }
  }
}

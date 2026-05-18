import ArgumentParser
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

  struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "List reminders"
    )

    @Option(name: .shortAndLong, help: "Filter by list name")
    var list: String?

    @Flag(name: .shortAndLong, help: "Include completed reminders")
    var completed = false

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      let service = ReminderService()
      let reminders = try await service.fetchReminders(
        listName: list,
        showCompleted: completed
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

    @Flag(name: .long, help: "Disable Shortcut integration")
    var noShortcuts = false

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      let locationTrigger = try locationOptions.resolveTrigger()

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
        useShortcuts: !noShortcuts
      )

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

    @Flag(name: .shortAndLong, help: "Mark as completed")
    var completed = false

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
      // Check against raw flag presence — not the parsed trigger — so a partial location
      // input alongside --clear-location surfaces the more helpful mutual-exclusion error
      // rather than the "must be provided together" one.
      if clearLocation, locationOptions.isPresent {
        throw EventCLIError.invalidInput(
          "Use either --location/--latitude/--longitude or --clear-location, not both."
        )
      }

      let locationTrigger = try locationOptions.resolveTrigger()

      let service = ReminderService()

      let reminder = try await service.updateReminder(
        id: id,
        title: title,
        completed: completed ? true : nil,
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
        useShortcuts: !noShortcuts
      )

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
      let service = ReminderService()
      try await service.deleteReminder(id: id)
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
      let service = ReminderService()
      let reminders = try await service.searchReminders(
        keyword: keyword,
        listName: list,
        showCompleted: completed
      )

      let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
      print(formatter.format(reminders))
    }
  }
}

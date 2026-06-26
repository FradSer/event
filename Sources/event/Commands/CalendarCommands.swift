import ArgumentParser
import EventModels
import Foundation

// MARK: - Calendar Commands

struct CalendarCommands: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "calendar",
    abstract: "Manage Apple Calendar (events, calendars)",
    subcommands: [List.self, Create.self, Update.self, Delete.self]
  )

  struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "List calendar events"
    )

    @Option(name: .shortAndLong, help: "Start date (yyyy-MM-dd)")
    var start: String?

    @Option(name: .shortAndLong, help: "End date (yyyy-MM-dd)")
    var end: String?

    @Option(name: .shortAndLong, help: "Filter by calendar name")
    var calendar: String?

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      #if canImport(EventKit)
        let service = CalendarService()
        let events = try await service.fetchEvents(
          startDate: start,
          endDate: end,
          calendarName: calendar
        )
      #else
        let backend = try await BackendFactory.makeCalendarBackend()
        let resolvedStart =
          start
          ?? DateFormatter.eventDate.string(from: Date())
        let resolvedEnd =
          end
          ?? DateFormatter.eventDate.string(
            from: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date())
        let events = try await backend.fetchEvents(
          start: resolvedStart,
          end: resolvedEnd,
          calendarName: calendar
        )
      #endif

      let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
      print(formatter.format(events))
    }
  }

  struct Create: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Create a new calendar event"
    )

    @Option(name: .shortAndLong, help: "Event title")
    var title: String

    @Option(
      name: .shortAndLong,
      help: "Start date (yyyy-MM-dd for all-day, yyyy-MM-dd HH:mm:ss for timed)"
    )
    var start: String

    @Option(
      name: .shortAndLong, help: "End date (yyyy-MM-dd for all-day, yyyy-MM-dd HH:mm:ss for timed)"
    )
    var end: String

    @Option(name: .shortAndLong, help: "Calendar name")
    var calendar: String?

    @Option(name: .shortAndLong, help: "Event location")
    var location: String?

    @Option(name: .shortAndLong, help: "Event notes")
    var notes: String?

    @Option(
      name: .long,
      help: "Alert minutes before start (repeatable, e.g. --alarm 15 --alarm 60)"
    )
    var alarm: [Int] = []

    @Flag(help: "Output in JSON format")
    var json = false

    func run() async throws {
      #if canImport(EventKit)
        let service = CalendarService()
        let event = try await service.createEvent(
          title: title,
          startDate: start,
          endDate: end,
          calendarName: calendar,
          location: location,
          notes: notes,
          alarmMinutes: alarm.isEmpty ? nil : alarm
        )
      #else
        let backend = try await BackendFactory.makeCalendarBackend()
        let isAllDay = Date.isAllDayFormat(start) && Date.isAllDayFormat(end)
        let params = CreateEventParams(
          title: title,
          calendarName: calendar,
          startDate: start,
          endDate: end,
          isAllDay: isAllDay,
          location: location,
          notes: notes
        )
        let event = try await backend.createEvent(params)
      #endif

      let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
      print(formatter.format(event))
    }
  }

  struct Update: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Update an existing calendar event"
    )

    @Option(name: .shortAndLong, help: "Event ID")
    var id: String

    @Option(name: .shortAndLong, help: "New title")
    var title: String?

    @Option(
      name: .shortAndLong,
      help: "New start date (yyyy-MM-dd for all-day, yyyy-MM-dd HH:mm:ss for timed)"
    )
    var start: String?

    @Option(
      name: .shortAndLong,
      help: "New end date (yyyy-MM-dd for all-day, yyyy-MM-dd HH:mm:ss for timed)"
    )
    var end: String?

    @Option(name: .shortAndLong, help: "New location")
    var location: String?

    @Option(name: .shortAndLong, help: "New notes")
    var notes: String?

    @Option(
      name: .long,
      help: "Replace all alerts with these minutes-before-start (repeatable)"
    )
    var alarm: [Int] = []

    @Option(
      name: .long,
      help: "Add alerts (minutes before start) to the existing ones (repeatable)"
    )
    var addAlarm: [Int] = []

    @Flag(name: .long, help: "Remove all alerts from the event")
    var clearAlarms = false

    @Flag(help: "Output in JSON format")
    var json = false

    func validate() throws {
      let modes = [!alarm.isEmpty, !addAlarm.isEmpty, clearAlarms].filter { $0 }.count
      if modes > 1 {
        throw ValidationError(
          "Use only one of --alarm, --add-alarm, or --clear-alarms.")
      }
    }

    func run() async throws {
      // alarmMinutes: nil = leave unchanged, [] = clear all, [..] = replace.
      // addAlarmMinutes: nil = none to add, [..] = append to existing.
      let alarmMinutes: [Int]? = clearAlarms ? [] : (alarm.isEmpty ? nil : alarm)
      let addAlarmMinutes: [Int]? = addAlarm.isEmpty ? nil : addAlarm
      #if canImport(EventKit)
        let service = CalendarService()
        let event = try await service.updateEvent(
          id: id,
          title: title,
          startDate: start,
          endDate: end,
          location: location,
          notes: notes,
          alarmMinutes: alarmMinutes,
          addAlarmMinutes: addAlarmMinutes
        )
      #else
        let backend = try await BackendFactory.makeCalendarBackend()
        let params = UpdateEventParams(
          title: title,
          startDate: start,
          endDate: end,
          location: location,
          notes: notes
        )
        let event = try await backend.updateEvent(id: id, params: params)
      #endif

      let formatter: OutputFormatter = json ? JSONFormatter() : MarkdownFormatter()
      print(formatter.format(event))
    }
  }

  struct Delete: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "Delete a calendar event"
    )

    @Option(name: .shortAndLong, help: "Event ID")
    var id: String

    @Option(help: "Delete span: this, future, or all")
    var span: String = "this"

    func run() async throws {
      #if canImport(EventKit)
        let service = CalendarService()
        try await service.deleteEvent(id: id, span: span)
      #else
        let backend = try await BackendFactory.makeCalendarBackend()
        try await backend.deleteEvent(id: id)
      #endif
      print("Event deleted successfully")
    }
  }
}

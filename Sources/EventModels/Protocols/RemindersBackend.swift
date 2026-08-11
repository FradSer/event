import Foundation

// MARK: - Reminders Backend Protocol

public protocol RemindersBackend: Sendable {
  func fetchReminders(
    listName: String?,
    showCompleted: Bool,
    startDate: String?,
    endDate: String?
  ) async throws -> [Reminder]
  func fetchReminder(byId id: String) async throws -> Reminder
  func createReminder(_ params: CreateReminderParams) async throws -> Reminder
  func updateReminder(id: String, params: UpdateReminderParams) async throws -> Reminder
  func deleteReminder(id: String) async throws
}

// MARK: - Create Reminder Params

public struct CreateReminderParams: Sendable {
  public let title: String
  public let listName: String?
  public let notes: String?
  public let url: String?
  public let dueDate: String?
  public let priority: Int
  public let startDate: String?

  public init(
    title: String,
    listName: String? = nil,
    notes: String? = nil,
    url: String? = nil,
    dueDate: String? = nil,
    priority: Int = 0,
    startDate: String? = nil
  ) {
    self.title = title
    self.listName = listName
    self.notes = notes
    self.url = url
    self.dueDate = dueDate
    self.priority = priority
    self.startDate = startDate
  }
}

// MARK: - Update Reminder Params

public struct UpdateReminderParams: Sendable {
  public let title: String?
  public let completed: Bool?
  public let notes: String?
  public let dueDate: String?
  public let clearDue: Bool
  public let startDate: String?
  public let clearStart: Bool
  public let priority: Int?
  public let url: String?

  public init(
    title: String? = nil,
    completed: Bool? = nil,
    notes: String? = nil,
    dueDate: String? = nil,
    clearDue: Bool = false,
    startDate: String? = nil,
    clearStart: Bool = false,
    priority: Int? = nil,
    url: String? = nil
  ) {
    self.title = title
    self.completed = completed
    self.notes = notes
    self.dueDate = dueDate
    self.clearDue = clearDue
    self.startDate = startDate
    self.clearStart = clearStart
    self.priority = priority
    self.url = url
  }
}

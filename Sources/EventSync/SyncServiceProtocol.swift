import AppleSyncKit
import EventModels

// MARK: - Sync Service Protocol

public enum SyncEntity: Sendable, Equatable {
  case reminders
  case calendarEvents
  case reminderLists

  public static let pullOrder: [SyncEntity] = [.reminderLists, .reminders, .calendarEvents]
  public static let pushOrder: [SyncEntity] = [.reminders, .calendarEvents, .reminderLists]
}

public struct FullSyncResult: Sendable {
  public let pull: [String: PullSummary]
  public let push: [String: PushResult]

  public init(pull: [String: PullSummary], push: [String: PushResult]) {
    self.pull = pull
    self.push = push
  }
}

/// Common interface for bidirectional sync services on both macOS (EventKit)
/// and Linux (SQLite). Both `SyncService` and `LinuxSyncService` conform
/// to this protocol.
public protocol SyncServiceProtocol: Sendable {
  func pushReminders() async throws -> PushResult
  func pushEvents() async throws -> PushResult
  func pushLists() async throws -> PushResult
  func pullReminders() async throws -> PullSummary
  func pullEvents() async throws -> PullSummary
  func pullLists() async throws -> PullSummary
  func push(entities: [SyncEntity]) async throws -> [String: PushResult]
  func pull(entities: [SyncEntity]) async throws -> [String: PullSummary]
  func fullSync(entities: [SyncEntity]) async throws -> FullSyncResult
  func shutdown() async throws
}

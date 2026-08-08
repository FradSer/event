import AppleSyncKit
import EventModels

// MARK: - Sync Service Protocol

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
  func shutdown() async throws
}

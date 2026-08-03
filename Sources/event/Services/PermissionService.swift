#if canImport(EventKit)

  import CoreGraphics
  import EventKit
  import EventModels
  import Foundation

  // MARK: - Permission Service

  actor PermissionService {
    private let eventStore = EKEventStore()

    /// Ensures the app has access to reminders
    func ensureRemindersAccess() async throws {
      let status = EKEventStore.authorizationStatus(for: .reminder)

      switch status {
      case .notDetermined:
        try Self.ensurePromptCanBeShown(kind: .reminders)
        let granted = try await requestFullAccessWithTimeout(kind: .reminders)
        if !granted {
          throw EventCLIError.permissionDenied(
            "Reminders access was denied. Please grant access in System Settings > Privacy & Security > Reminders."
          )
        }
      case .restricted:
        throw EventCLIError.permissionDenied("Reminders access is restricted by system policy.")
      case .denied:
        throw EventCLIError.permissionDenied(
          "Reminders access was denied. Please grant access in System Settings > Privacy & Security > Reminders."
        )
      case .fullAccess:
        // Already have access
        break
      case .writeOnly:
        throw EventCLIError.permissionDenied(
          "Only write access to reminders. Full access is required."
        )
      @unknown default:
        throw EventCLIError.permissionDenied("Unknown permission status for reminders.")
      }
    }

    /// Ensures the app has access to calendar events
    func ensureCalendarAccess() async throws {
      let status = EKEventStore.authorizationStatus(for: .event)

      switch status {
      case .notDetermined:
        try Self.ensurePromptCanBeShown(kind: .events)
        let granted = try await requestFullAccessWithTimeout(kind: .events)
        if !granted {
          throw EventCLIError.permissionDenied(
            "Calendar access was denied. Please grant access in System Settings > Privacy & Security > Calendars."
          )
        }
      case .restricted:
        throw EventCLIError.permissionDenied("Calendar access is restricted by system policy.")
      case .denied:
        throw EventCLIError.permissionDenied(
          "Calendar access was denied. Please grant access in System Settings > Privacy & Security > Calendars."
        )
      case .fullAccess:
        // Already have access
        break
      case .writeOnly:
        throw EventCLIError.permissionDenied(
          "Only write access to calendar. Full access is required."
        )
      @unknown default:
        throw EventCLIError.permissionDenied("Unknown permission status for calendar.")
      }
    }

    // MARK: - Prompt handling

    /// EventKit access kind, used to pick the matching `requestFullAccess*`
    /// API inside the prompt task without capturing the non-Sendable
    /// `EKEventStore` across isolation boundaries. Also the single source of
    /// truth for the display name that error messages and the MCP server's
    /// permission-domain classification key off of.
    private enum AccessKind: Sendable {
      case reminders
      case events

      var domain: String {
        switch self {
        case .reminders: "Reminders"
        case .events: "Calendar"
        }
      }
    }

    /// The TCC prompt can only be rendered when this process runs inside a
    /// GUI (window server) session. Without one — SSH, launchd daemons, some
    /// launchd agents — `requestFullAccess*` never returns and the caller
    /// hangs forever (issue #113), so fail fast with a permission error
    /// instead of blocking the MCP server.
    private static func ensurePromptCanBeShown(kind: AccessKind) throws {
      guard CGSessionCopyCurrentDictionary() != nil else {
        throw EventCLIError.permissionDenied(
          "No GUI session is available to display the \(kind.domain) permission prompt. "
            + "Run from a logged-in GUI session, or grant access interactively first."
        )
      }
    }

    /// Runs the EventKit access prompt with a bounded wait. When the prompt
    /// can never be rendered (headless/launchd), `requestFullAccess*` never
    /// completes, and it is not cancellation-aware — so this uses
    /// fire-and-forget tasks plus a single-resume gate instead of a task
    /// group, which would await the abandoned request forever on scope exit.
    private func requestFullAccessWithTimeout(kind: AccessKind) async throws -> Bool {
      try await withCheckedThrowingContinuation { continuation in
        let gate = ResumeGate()
        let timeoutMessage = Self.timeoutMessage(domain: kind.domain)
        Task {
          do {
            let granted = try await requestFullAccess(kind: kind)
            if gate.claim() { continuation.resume(returning: granted) }
          } catch {
            if gate.claim() {
              // Keep the failure domain-typed: `requestFullAccess*` throws on
              // authorization failures (e.g. TCC denying the request itself),
              // and the MCP server classifies errors by the domain word.
              continuation.resume(
                throwing: EventCLIError.permissionDenied(
                  "\(kind.domain) access could not be requested: \(error.localizedDescription)"
                ))
            }
          }
        }
        Task {
          try? await Task.sleep(for: .milliseconds(Int64(Self.timeoutMilliseconds())))
          if gate.claim() {
            continuation.resume(throwing: EventCLIError.permissionDenied(timeoutMessage))
          }
        }
      }
    }

    private func requestFullAccess(kind: AccessKind) async throws -> Bool {
      switch kind {
      case .reminders:
        return try await eventStore.requestFullAccessToReminders()
      case .events:
        return try await eventStore.requestFullAccessToEvents()
      }
    }

    private static func timeoutMessage(domain: String) -> String {
      // Neutral about the cause: the prompt may be undisplayable (headless or
      // launchd) or simply unanswered — both present identically to the caller.
      "Timed out waiting for the \(domain) access prompt. The prompt could not be displayed "
        + "or was left unanswered (headless/launchd context, or no response in time). Grant "
        + "access in System Settings > Privacy & Security > \(domain), or raise "
        + "EVENT_PERMISSION_TIMEOUT_MS (keep it below EVENTKIT_CLI_TIMEOUT_MS when run under "
        + "the MCP server)."
    }

    /// How long to wait for the TCC prompt before giving up (default 15 s,
    /// overridable via `EVENT_PERMISSION_TIMEOUT_MS`). Deliberately below the
    /// MCP server's `EVENTKIT_CLI_TIMEOUT_MS` kill timeout (30 s) so the CLI
    /// answers with a domain-typed permission error instead of being
    /// SIGKILLed with a generic one.
    static func timeoutMilliseconds(
      environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UInt64 {
      let raw = environment["EVENT_PERMISSION_TIMEOUT_MS"]?
        .trimmingCharacters(in: .whitespaces)
      guard let raw, let ms = UInt64(raw), ms > 0 else {
        return 15_000
      }
      // Cap at 1 h so the Int64 conversion for `Task.sleep(for:)` cannot
      // overflow (which would trap the process) on absurd env values.
      return min(ms, 3_600_000)
    }
  }

  /// Single-resume gate so the TCC completion and the timeout task cannot
  /// both resume the checked continuation (which would crash the process).
  /// Internal (not private) so the claim-once contract is unit-testable.
  final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    /// Returns true exactly once; subsequent calls return false.
    func claim() -> Bool {
      lock.lock()
      defer { lock.unlock() }
      guard !resumed else { return false }
      resumed = true
      return true
    }
  }

#endif

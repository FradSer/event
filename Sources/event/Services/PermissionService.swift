import EventKit
import Foundation

// MARK: - Permission Service

actor PermissionService {
    private let eventStore = EKEventStore()

    /// Ensures the app has access to reminders
    func ensureRemindersAccess() async throws {
        let status = EKEventStore.authorizationStatus(for: .reminder)

        switch status {
        case .notDetermined:
            let granted = try await eventStore.requestFullAccessToReminders()
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
            let granted = try await eventStore.requestFullAccessToEvents()
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
}

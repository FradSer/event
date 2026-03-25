import ArgumentParser
import EventModels
import Foundation

// MARK: - Sync Commands (Linux / D1-only)

struct SyncCommands: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Sync configuration and status",
        subcommands: [Config.self, Status.self]
    )

    // MARK: - Config

    struct Config: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Configure sync settings"
        )

        @Option(help: "Cloudflare Worker API URL")
        var apiUrl: String

        @Option(help: "API Bearer token")
        var apiToken: String

        @Option(help: "Device identifier (e.g. linux-server)")
        var deviceId: String

        func run() async throws {
            let config = SyncConfig(apiURL: apiUrl, apiToken: apiToken, deviceId: deviceId)
            try SyncConfigStore.save(config)
            print("Sync config saved to \(SyncConfigStore.configPath)")
        }
    }

    // MARK: - Status

    struct Status: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show sync configuration and cursor state"
        )

        func run() async throws {
            let config = try SyncConfigStore.load()
            let cursors = SyncConfigStore.loadCursors()

            print("API URL: \(config.apiURL)")
            print("Device ID: \(config.deviceId)")
            print("Token: \(String(config.apiToken.prefix(8)))...")
            print("")
            print("Last sync cursors:")
            print("  Reminders:       \(cursors.reminders ?? "never")")
            print("  Calendar events: \(cursors.calendarEvents ?? "never")")
            print("  Reminder lists:  \(cursors.reminderLists ?? "never")")
        }
    }
}

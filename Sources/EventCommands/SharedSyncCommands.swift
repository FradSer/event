import AppleSyncKit
import ArgumentParser
import EventModels
import EventSync
import Foundation

// MARK: - Shared Sync Subcommands

public struct SyncConfigCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "config",
    abstract: "Configure sync settings"
  )

  @Option(help: "Cloudflare Worker API URL")
  public var apiUrl: String

  @Option(help: "API Bearer token")
  public var apiToken: String

  @Option(help: "Device identifier (default: system hostname)")
  public var deviceId: String?

  public init() {}

  public func run() async throws {
    let resolvedDeviceId = deviceId ?? ProcessInfo.processInfo.hostName
    let config = SyncConfig(apiURL: apiUrl, apiToken: apiToken, deviceId: resolvedDeviceId)
    try SyncConfigStore.save(config)
    print("Sync config saved to \(SyncConfigStore.configPath)")
  }
}

public struct SyncStatusCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "status",
    abstract: "Show sync configuration and cursor state"
  )

  public init() {}

  public func run() async throws {
    let config = try SyncConfigStore.load()
    let cursors = SyncConfigStore.loadCursors()

    let source =
      SyncConfigStore.hasEnvironmentConfig()
      ? "environment variables" : SyncConfigStore.configPath
    print("Config source: \(source)")
    print("API URL: \(config.apiURL)")
    print("Device ID: \(config.deviceId)")
    print("Token: \(String(config.apiToken.prefix(4)))...")
    print("")
    print("Last sync cursors:")
    print("  Reminders:       \(cursors.reminders ?? "never")")
    print("  Calendar events: \(cursors.calendarEvents ?? "never")")
    print("  Reminder lists:  \(cursors.reminderLists ?? "never")")
  }
}

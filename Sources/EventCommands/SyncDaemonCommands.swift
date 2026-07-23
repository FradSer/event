import AppleSyncKit
import ArgumentParser
import EventSync
import Foundation

// MARK: - Daemon (launchd background sync)

/// Installs and manages a launchd LaunchAgent that runs `event sync run
/// --daemon` on a fixed interval. There is no long-running process: launchd
/// starts the CLI, one full sync runs, and the process exits. The encryption
/// key is captured into the plist's EnvironmentVariables at install time
/// because launchd jobs do not inherit the shell environment.
public struct SyncDaemonCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "daemon",
    abstract: "Manage background sync via launchd",
    discussion: """
      Installs a per-user LaunchAgent (~/Library/LaunchAgents/\(label).plist) \
      that runs 'event sync run --daemon' every --interval seconds. The plist \
      holds EVENT_ENCRYPTION_KEY (mode 0600) since launchd jobs don't see your \
      shell exports; re-run 'install' after rotating the key. Overlaps with a \
      manual 'event sync' are skipped quietly via the sync lock.
      """,
    subcommands: [Install.self, Uninstall.self, Status.self],
    defaultSubcommand: Status.self
  )

  static let label = "ai.fradser.event-sync"
  static let encryptionKeyEnv = "EVENT_ENCRYPTION_KEY"

  public init() {}

  /// Builds the LaunchAgent spec: resolved binary path + key from the
  /// environment. Throws when the key is not exported.
  static func makeSpec(
    interval: Int,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    executablePath: String = CommandLine.arguments[0]
  ) throws -> LaunchAgentSpec {
    guard let key = environment[encryptionKeyEnv], !key.isEmpty else {
      throw SyncError.invalidInput(
        "\(encryptionKeyEnv) is not set. Export it first (same key as your other devices), "
          + "then re-run 'event sync daemon install'.")
    }
    let resolvedPath = URL(fileURLWithPath: executablePath).standardizedFileURL
      .resolvingSymlinksInPath().path
    return LaunchAgentSpec(
      label: label,
      programArguments: [resolvedPath, "sync", "run", "--daemon"],
      startInterval: interval,
      environment: [
        encryptionKeyEnv: key,
        "PATH": "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin",
      ],
      logPath: SyncConfigStore.daemonLogPath)
  }

  public struct Install: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
      abstract: "Install and start the launchd background sync agent")

    @Option(help: "Sync interval in seconds (default: 1800 = 30 minutes)")
    public var interval: Int = 1800

    public init() {}

    public func run() async throws {
      let spec = try SyncDaemonCommand.makeSpec(interval: interval)
      try LaunchAgentManager().install(spec)
      let plistPath = LaunchAgentManager().plistURL(for: SyncDaemonCommand.label).path
      print("Wrote \(plistPath)")
      print("Daemon installed and started: event syncs every \(interval) seconds.")
      print("Logs: \(SyncConfigStore.daemonLogPath)")
      print("Run 'event sync daemon status' to check on it.")
    }
  }

  public struct Uninstall: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
      abstract: "Stop and remove the launchd background sync agent")

    public init() {}

    public func run() async throws {
      try LaunchAgentManager().uninstall(label: SyncDaemonCommand.label)
      print("Daemon uninstalled (LaunchAgent \(SyncDaemonCommand.label) removed).")
    }
  }

  public struct Status: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
      abstract: "Show daemon state and the last background sync result")

    public init() {}

    public func run() async throws {
      let status = LaunchAgentManager().status(label: SyncDaemonCommand.label)
      switch status.state {
      case .notLoaded:
        print("Daemon: not installed (run 'event sync daemon install')")
        return
      case .running:
        print("Daemon: running now")
      case .waiting:
        print("Daemon: installed (waiting for next interval)")
      case .unknown:
        print("Daemon: installed (state unknown)")
      }
      if let exitCode = status.lastExitCode {
        print("Last exit code: \(exitCode)")
      }

      guard let lastRun = SyncConfigStore.loadLastRun() else {
        print("Last run: never")
        return
      }
      print(
        "Last run: \(lastRun.finishedAt.formatted(date: .abbreviated, time: .standard)) "
          + (lastRun.succeeded ? "(ok)" : "(FAILED)"))
      if let error = lastRun.error {
        print("  Error: \(error)")
      }
      for line in lastRun.summary {
        print("  \(line)")
      }
    }
  }
}

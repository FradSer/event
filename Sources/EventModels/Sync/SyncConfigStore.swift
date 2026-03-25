import Foundation

// MARK: - Sync Config Store

public enum SyncConfigStore {
    public static var configPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.config/event-sync/config.json"
    }

    public static var cursorsPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.config/event-sync/cursors.json"
    }

    public static func load() throws -> SyncConfig {
        let url = URL(fileURLWithPath: configPath)
        guard FileManager.default.fileExists(atPath: configPath) else {
            throw EventCLIError.notFound(
                "Sync config not found. Run 'event sync config --api-url <URL> --api-token <TOKEN> --device-id <ID>' first."
            )
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SyncConfig.self, from: data)
    }

    public static func save(_ config: SyncConfig) throws {
        let dir = URL(fileURLWithPath: configPath).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(config)
        try data.write(to: URL(fileURLWithPath: configPath), options: .atomic)
    }

    public static func loadCursors() -> SyncCursors {
        guard FileManager.default.fileExists(atPath: cursorsPath),
            let data = try? Data(contentsOf: URL(fileURLWithPath: cursorsPath)),
            let cursors = try? JSONDecoder().decode(SyncCursors.self, from: data)
        else {
            return SyncCursors()
        }
        return cursors
    }

    public static func saveCursors(_ cursors: SyncCursors) throws {
        let dir = URL(fileURLWithPath: cursorsPath).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(cursors)
        try data.write(to: URL(fileURLWithPath: cursorsPath), options: .atomic)
    }
}

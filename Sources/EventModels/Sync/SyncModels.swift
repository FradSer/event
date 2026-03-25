import Foundation

// MARK: - Sync Configuration

public struct SyncConfig: Codable, Sendable {
    public let apiURL: String
    public let apiToken: String
    public let deviceId: String

    public init(apiURL: String, apiToken: String, deviceId: String) {
        self.apiURL = apiURL
        self.apiToken = apiToken
        self.deviceId = deviceId
    }
}

// MARK: - Sync Results

public struct PushResult: Codable, Sendable {
    public let synced: Int
    public let skipped: Int
}

public struct PullResponse<T: Codable & Sendable>: Sendable {
    public let items: [PullItem<T>]
    public let cursor: String
    public let hasMore: Bool
}

public struct PullItem<T: Codable & Sendable>: Sendable {
    public let id: String
    public let data: T
    public let deleted: Bool
    public let updatedAt: String
}

// MARK: - Sync Cursors

public struct SyncCursors: Codable, Sendable {
    public var reminders: String?
    public var calendarEvents: String?
    public var reminderLists: String?

    public init(reminders: String? = nil, calendarEvents: String? = nil, reminderLists: String? = nil) {
        self.reminders = reminders
        self.calendarEvents = calendarEvents
        self.reminderLists = reminderLists
    }
}

// MARK: - Push Request Models

struct PushRequestItem<T: Codable>: Codable {
    let id: String
    let data: T
    let lastModified: String

    enum CodingKeys: String, CodingKey {
        case id
        case data
        case lastModified = "last_modified"
    }
}

struct PushRequest<T: Codable>: Codable {
    let deviceId: String
    let items: [PushRequestItem<T>]

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case items
    }
}

// MARK: - Pull Response Models

struct PullResponseDTO: Codable {
    let items: [PullItemDTO]
    let cursor: String
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case items
        case cursor
        case hasMore = "has_more"
    }
}

struct PullItemDTO: Codable {
    let id: String
    let data: AnyCodable
    let deleted: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case data
        case deleted
        case updatedAt = "updated_at"
    }
}

// MARK: - AnyCodable

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = ()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        default:
            try container.encodeNil()
        }
    }
}

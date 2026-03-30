import EventModels
import Foundation

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
  let data: JSONValue
  let deleted: Bool
  let updatedAt: String

  enum CodingKeys: String, CodingKey {
    case id
    case data
    case deleted
    case updatedAt = "updated_at"
  }
}

enum PullItemDecoder {
  static func decodeItems<T: Codable & Sendable>(
    from items: [PullItemDTO],
    entity: String
  ) throws -> [PullItem<T>] {
    var decodedItems: [PullItem<T>] = []
    decodedItems.reserveCapacity(items.count)

    for itemDTO in items {
      do {
        let jsonData = try JSONSerialization.data(withJSONObject: itemDTO.data.rawValue)
        let decoded = try JSONDecoder().decode(T.self, from: jsonData)
        decodedItems.append(
          PullItem(
            id: itemDTO.id,
            data: decoded,
            deleted: itemDTO.deleted,
            updatedAt: itemDTO.updatedAt
          )
        )
      } catch {
        throw EventCLIError.unknown(
          "Failed to decode \(entity) item \(itemDTO.id): \(error.localizedDescription)"
        )
      }
    }

    return decodedItems
  }
}

// MARK: - JSONValue (Sendable replacement for AnyCodable)

enum JSONValue: Codable, Sendable {
  case string(String)
  case int(Int)
  case double(Double)
  case bool(Bool)
  case array([JSONValue])
  case object([String: JSONValue])
  case null

  /// Convert to Foundation object suitable for JSONSerialization
  var rawValue: Any {
    switch self {
    case .string(let v): return v
    case .int(let v): return v
    case .double(let v): return v
    case .bool(let v): return v
    case .array(let v): return v.map { $0.rawValue }
    case .object(let v): return v.mapValues { $0.rawValue }
    case .null: return NSNull()
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let dict = try? container.decode([String: JSONValue].self) {
      self = .object(dict)
    } else if let array = try? container.decode([JSONValue].self) {
      self = .array(array)
    } else if let string = try? container.decode(String.self) {
      self = .string(string)
    } else if let int = try? container.decode(Int.self) {
      self = .int(int)
    } else if let double = try? container.decode(Double.self) {
      self = .double(double)
    } else if let bool = try? container.decode(Bool.self) {
      self = .bool(bool)
    } else if container.decodeNil() {
      self = .null
    } else {
      throw DecodingError.typeMismatch(
        JSONValue.self,
        DecodingError.Context(
          codingPath: decoder.codingPath, debugDescription: "Unsupported JSON type")
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let v): try container.encode(v)
    case .int(let v): try container.encode(v)
    case .double(let v): try container.encode(v)
    case .bool(let v): try container.encode(v)
    case .array(let v): try container.encode(v)
    case .object(let v): try container.encode(v)
    case .null: try container.encodeNil()
    }
  }
}

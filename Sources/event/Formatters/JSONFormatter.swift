import Foundation

// MARK: - JSON Formatter

struct JSONFormatter: OutputFormatter {
    func format<T: Encodable>(_ data: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(data),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            return "{\"error\": \"Failed to encode data\"}"
        }

        return jsonString
    }
}

import Foundation

// MARK: - Output Formatter Protocol

public protocol OutputFormatter {
    func format<T: Encodable>(_ data: T) -> String
}

import Foundation

// MARK: - Output Formatter Protocol

protocol OutputFormatter {
    func format<T: Encodable>(_ data: T) -> String
}

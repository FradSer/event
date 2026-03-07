import Foundation

// MARK: - Subtask Model

struct Subtask: Codable {
    let id: String
    let title: String
    let isCompleted: Bool
}

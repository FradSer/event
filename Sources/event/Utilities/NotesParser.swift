import Foundation
import Security

// MARK: - Parsed Notes

struct ParsedNotes {
    var userNotes: String
    var tags: [String]
    var subtasks: [Subtask]
}

// MARK: - Notes Parser

/// Unified parser for all EventKit-unsupported reminder data stored in the notes field.
///
/// Format:
/// ```
/// User-written notes
/// ---
/// tags: #tag1 #tag2
/// [ ] Subtask title {id}
/// [x] Completed subtask {id}
/// ```
///
/// Rules:
/// - Everything before the first `---` line is user notes
/// - `tags:` line lists space-separated hashtags (supports Unicode/CJK via `\p{L}\p{N}`)
/// - `[ ]` / `[x]` lines are subtasks; title precedes ID
/// - Metadata block is omitted entirely when empty
enum NotesParser {
    private static let separator = "---"
    private static let tagsPrefix = "tags:"
    private static let subtaskPattern = #"^\[([ x])\]\s*(.+?)\s*\{([a-f0-9]+)\}$"#
    private static let tagPattern = #"#([\p{L}\p{N}_-]+)"#

    // MARK: Parse

    static func parse(_ notes: String?) -> ParsedNotes {
        guard let notes = notes, !notes.isEmpty else {
            return ParsedNotes(userNotes: "", tags: [], subtasks: [])
        }

        if let range = notes.range(of: "\n\(separator)\n") {
            let userNotes = String(notes[..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let (tags, subtasks) = parseMetadata(String(notes[range.upperBound...]))
            return ParsedNotes(userNotes: userNotes, tags: tags, subtasks: subtasks)
        }

        if notes.hasPrefix("\(separator)\n") {
            let (tags, subtasks) = parseMetadata(String(notes.dropFirst(separator.count + 1)))
            return ParsedNotes(userNotes: "", tags: tags, subtasks: subtasks)
        }

        return ParsedNotes(
            userNotes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: [],
            subtasks: []
        )
    }

    private static func parseMetadata(_ meta: String) -> ([String], [Subtask]) {
        var tags: [String] = []
        var subtasks: [Subtask] = []

        guard let subtaskRegex = try? NSRegularExpression(pattern: subtaskPattern),
              let tagRegex = try? NSRegularExpression(pattern: tagPattern)
        else {
            return ([], [])
        }

        for line in meta.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix(tagsPrefix) {
                let tagLine = String(trimmed.dropFirst(tagsPrefix.count))
                    .trimmingCharacters(in: .whitespaces)
                let range = NSRange(tagLine.startIndex..., in: tagLine)
                tags = tagRegex.matches(in: tagLine, range: range).compactMap { match in
                    Range(match.range(at: 1), in: tagLine).map { String(tagLine[$0]) }
                }
            } else {
                let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
                if let match = subtaskRegex.firstMatch(in: trimmed, range: nsRange),
                   let checkboxRange = Range(match.range(at: 1), in: trimmed),
                   let titleRange = Range(match.range(at: 2), in: trimmed),
                   let idRange = Range(match.range(at: 3), in: trimmed)
                {
                    subtasks.append(Subtask(
                        id: String(trimmed[idRange]),
                        title: String(trimmed[titleRange]),
                        isCompleted: String(trimmed[checkboxRange]) == "x"
                    ))
                }
            }
        }

        return (tags, subtasks)
    }

    // MARK: Serialize

    static func serialize(_ parsed: ParsedNotes) -> String {
        var metaLines: [String] = []

        if !parsed.tags.isEmpty {
            let tagLine = parsed.tags.map { "#\($0)" }.joined(separator: " ")
            metaLines.append("\(tagsPrefix) \(tagLine)")
        }

        for subtask in parsed.subtasks {
            let checkbox = subtask.isCompleted ? "[x]" : "[ ]"
            metaLines.append("\(checkbox) \(subtask.title) {\(subtask.id)}")
        }

        guard !metaLines.isEmpty else { return parsed.userNotes }

        let metaBlock = "\(separator)\n" + metaLines.joined(separator: "\n")
        return parsed.userNotes.isEmpty ? metaBlock : "\(parsed.userNotes)\n\(metaBlock)"
    }

    // MARK: ID Generation

    static func generateSubtaskId() -> String {
        var bytes = [UInt8](repeating: 0, count: 4)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}

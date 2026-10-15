import Foundation

// MARK: - Diagnostic Note

/// Writes a diagnostic note to stderr.
///
/// Stdout carries the JSON or plain-text result that a caller parses. A note
/// printed to stdout makes a successful write look like a parse failure, so
/// every note goes to stderr instead.
public enum DiagnosticNote {
  public static func write(_ message: String) {
    FileHandle.standardError.write(Data(message.utf8))
  }
}

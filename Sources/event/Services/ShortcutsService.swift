import Foundation

// MARK: - Shortcuts Service

/// Service for interacting with the macOS Shortcuts CLI
actor ShortcutsService {
    /// Checks if a given shortcut is installed
    /// - Parameter name: The name of the shortcut to check
    /// - Returns: True if installed, false otherwise
    func isShortcutInstalled(name: String) async throws -> Bool {
        let task = Process()
        let pipe = Pipe()

        task.standardOutput = pipe
        task.standardError = pipe
        task.arguments = ["list"]
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                return lines.contains(name)
            }
            return false
        } catch {
            return false
        }
    }

    /// Runs a shortcut with the given JSON-encoded input via stdin
    /// - Parameters:
    ///   - name: The name of the shortcut to run
    ///   - input: The encodable input to pass as JSON
    /// - Returns: The standard output string (usually the UUID for this use case)
    func runShortcut<T: Encodable>(name: String, input: T) async throws -> String {
        let encoder = JSONEncoder()
        let inputData = try encoder.encode(input)

        let task = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()

        task.standardInput = inputPipe
        task.standardOutput = outputPipe
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        task.arguments = ["run", name]

        try task.run()

        // Write the JSON payload to standard input
        try inputPipe.fileHandleForWriting.write(contentsOf: inputData)
        try inputPipe.fileHandleForWriting.close()

        task.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

        if task.terminationStatus != 0 {
            throw EventCLIError.invalidInput("Shortcut execution failed with status \(task.terminationStatus)")
        }

        guard let output = String(data: outputData, encoding: .utf8) else {
            throw EventCLIError.invalidInput("Failed to decode shortcut output")
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

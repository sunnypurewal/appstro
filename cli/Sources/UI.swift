import Foundation

public enum UI {
    public static func step<T>(
        _ message: String,
        emoji: String,
        block: () async throws -> T
    ) async throws -> T {
        print("\(emoji) \(message)...", terminator: "")
        fflush(stdout)
        
        let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
        let animationTask = Task {
            var index = 0
            while !Task.isCancelled {
                let frame = frames[index % frames.count]
                // Use \r to return to start of line, then \u{1B}[K to clear line
                print("\r\(emoji) \(message)... \(frame)", terminator: "")
                fflush(stdout)
                index += 1
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        
        do {
            let result = try await block()
            animationTask.cancel()
            print("\r\u{1B}[K✅ \(message) complete!")
            return result
        } catch {
            animationTask.cancel()
            print("\r\u{1B}[K❌ \(message) failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    public static func success(_ message: String) {
        print("✅ \(message)")
    }
    
    public static func error(_ message: String) {
        print("❌ \(message)")
    }
    
    public static func info(_ message: String, emoji: String = "ℹ️") {
        print("\(emoji) \(message)")
    }

    public static func prompt(_ message: String, defaultValue: String? = nil) -> String {
        if let defaultValue = defaultValue {
            print("❓ \(message) [\(defaultValue)]: ", terminator: "")
        } else {
            print("❓ \(message): ", terminator: "")
        }
        fflush(stdout)
        
        guard let input = readLine(strippingNewline: true), !input.isEmpty else {
            return defaultValue ?? ""
        }
        return input
    }

    public static func openFile(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.path]
        try? process.run()
    }

    public static func closeFile(_ url: URL) {
        let script = "tell application \"Preview\" to close (every window whose name contains \"\(url.lastPathComponent)\")"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }
}
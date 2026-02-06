import Foundation
import AppstroCore

public final class DefaultUI: UserInterface, @unchecked Sendable {
    public init() {}

    public func prompt(_ text: String, defaultValue: String? = nil) -> String {
        if let defaultValue = defaultValue {
            print("❓ \(text) [\(defaultValue)]: ", terminator: "")
        } else {
            print("❓ \(text): ", terminator: "")
        }
        fflush(stdout)
        
        guard let input = readLine(strippingNewline: true), !input.isEmpty else {
            return defaultValue ?? ""
        }
        return input
    }
    
    public func info(_ message: String, emoji: String? = "ℹ️") {
        if let emoji = emoji {
            print("\(emoji) \(message)")
        } else {
            print("\(message)")
        }
    }
    
    public func success(_ message: String) {
        print("✅ \(message)")
    }
    
    public func error(_ message: String) {
        print("❌ \(message)")
    }

    public func openURL(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.absoluteString]
        try? process.run()
    }

    public func openFile(_ url: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.path]
        try? process.run()
    }

    public func closeFile(_ url: URL) {
        let script = "tell application \"Preview\" to close (every window whose name contains \"\(url.lastPathComponent)\")"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

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
}

// Keep the enum for backward compatibility where static calls are used, but delegate to a live instance if needed.
// Or just keep the enum methods as they were but have them use Environment.live.ui if we want to migrate fully.
// For now, let's keep the enum methods as static for convenience in UI-heavy code, but allow the Environment to hold a protocol-conforming instance.
public enum UI {
    public static func step<T>(
        _ message: String,
        emoji: String,
        block: () async throws -> T
    ) async throws -> T {
        try await DefaultUI.step(message, emoji: emoji, block: block)
    }
    
    public static func success(_ message: String) {
        Environment.live.ui.success(message)
    }
    
    public static func error(_ message: String) {
        Environment.live.ui.error(message)
    }
    
    public static func info(_ message: String, emoji: String = "ℹ️") {
        Environment.live.ui.info(message, emoji: emoji)
    }

    public static func prompt(_ message: String, defaultValue: String? = nil) -> String {
        Environment.live.ui.prompt(message, defaultValue: defaultValue)
    }

    public static func openURL(_ url: URL) {
        Environment.live.ui.openURL(url)
    }

    public static func openFile(_ url: URL) {
        Environment.live.ui.openFile(url)
    }

    public static func closeFile(_ url: URL) {
        Environment.live.ui.closeFile(url)
    }
}

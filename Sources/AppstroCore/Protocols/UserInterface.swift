import Foundation

public protocol UserInterface: Sendable {
    func prompt(_ text: String, defaultValue: String?) -> String
    func info(_ message: String, emoji: String?)
    func success(_ message: String)
    func error(_ message: String)
    func openURL(_ url: URL)
    func openFile(_ url: URL)
    func closeFile(_ url: URL)
}

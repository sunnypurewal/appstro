import Foundation

public struct AppPreferences: Codable, Sendable {
	public var lastUsedPrefix: String?

	public init(lastUsedPrefix: String? = nil) {
		self.lastUsedPrefix = lastUsedPrefix
	}
}

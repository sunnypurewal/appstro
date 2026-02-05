import Foundation

public struct AppInfo: Sendable {
	public let id: String
	public let name: String
	public let bundleId: String

	public init(id: String, name: String, bundleId: String) {
		self.id = id
		self.name = name
		self.bundleId = bundleId
	}
}

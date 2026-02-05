import Foundation

public struct DraftVersion: Sendable {
	public let version: String
	public let id: String
	public let state: AppVersionState

	public init(version: String, id: String, state: AppVersionState) {
		self.version = version
		self.id = id
		self.state = state
	}
}
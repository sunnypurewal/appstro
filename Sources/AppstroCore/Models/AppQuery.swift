import Foundation

public struct AppQuery: Sendable {
	public enum QueryType: Sendable {
		case name(String)
		case bundleId(String)
	}
	public let type: QueryType

	public init(type: QueryType) {
		self.type = type
	}
}

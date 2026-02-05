import Foundation

public struct ContentRightsAnalysis: Codable, Sendable {
	public let usesThirdPartyContent: Bool
	public let reasoning: String

	public init(usesThirdPartyContent: Bool, reasoning: String) {
		self.usesThirdPartyContent = usesThirdPartyContent
		self.reasoning = reasoning
	}
}

import Foundation

public struct GeneratedMetadata: Codable, Sendable {
	public let description: String
	public let keywords: String
	public let promotionalText: String
	public let reviewNotes: String
	public let whatsNew: String?

	public init(description: String, keywords: String, promotionalText: String, reviewNotes: String, whatsNew: String? = nil) {
		self.description = description
		self.keywords = keywords
		self.promotionalText = promotionalText
		self.reviewNotes = reviewNotes
		self.whatsNew = whatsNew
	}
}

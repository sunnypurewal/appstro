import Foundation

public struct ScreenshotDescription: Sendable, Codable {
	public let keyword: String
	public let title: String

	public init(keyword: String, title: String) {
		self.keyword = keyword
		self.title = title
	}
}

public protocol AIService: Sendable {
	func generateMetadata(appName: String, codeContext: String, userPitch: String?) async throws -> GeneratedMetadata
	func describeScreenshot(imageURL: URL, appName: String, appDescription: String) async throws -> ScreenshotDescription
	func analyzeContentRights(appName: String, description: String) async throws -> ContentRightsAnalysis?
	func suggestAgeRatings(appName: String, description: String, codeContext: String) async throws -> SuggestedAgeRatings?
	func analyzeDataCollection(appName: String, codeContext: String) async throws -> DataCollectionAnalysis?
}

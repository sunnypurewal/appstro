import Foundation

public protocol ScreenshotService: Sendable {
	func uploadScreenshots(versionId: String, processedDirectory: URL, deviceTypes: [String]?) async throws
}

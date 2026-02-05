import Foundation

public protocol ScreenshotService: Sendable {
	func uploadScreenshots(versionId: String, processedDirectory: URL) async throws
}

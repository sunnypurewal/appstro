import Foundation

public protocol VersionService: Sendable {
	func findDraftVersion(for appId: String) async throws -> DraftVersion?
	
	/// Fetches the most recent builds for the specified app and version.
	/// - Returns: A list of builds, sorted by uploaded date descending (newest first).
	func fetchBuilds(appId: String, version: String?) async throws -> [BuildInfo]
	
	func attachBuildToVersion(versionId: String, buildId: String) async throws
	func createVersion(appId: String, versionString: String, platform: String) async throws -> DraftVersion
	func fetchAttachedBuildId(versionId: String) async throws -> String?
}
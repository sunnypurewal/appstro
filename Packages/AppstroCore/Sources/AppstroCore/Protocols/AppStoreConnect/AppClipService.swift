import Foundation

public protocol AppClipService: Sendable {
	func fetchDefaultExperienceId(versionId: String) async throws -> String?
	func fetchAdvancedExperienceIds(appId: String) async throws -> [String]
	func deleteDefaultExperience(id: String) async throws
	func deactivateAdvancedExperience(id: String) async throws
}

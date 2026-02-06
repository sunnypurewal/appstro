import Foundation

public protocol ReviewService: Sendable {
	func fetchContactInfo() async throws -> ContactInfo
	func submitForReview(appId: String, versionId: String) async throws
	func cancelReviewSubmission(appId: String) async throws
	func uploadReviewAttachment(versionId: String, fileURL: URL) async throws
	func getDeveloperEmailDomain() async throws -> String
	func getTeamName() async throws -> String
}

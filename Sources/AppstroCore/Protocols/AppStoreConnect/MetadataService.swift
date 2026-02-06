import Foundation

public protocol MetadataService: Sendable {
	func updateMetadata(versionId: String, metadata: GeneratedMetadata, urls: (support: String, marketing: String), copyright: String, contactInfo: ContactInfo) async throws
	func updatePrivacyPolicy(appId: String, url: URL) async throws

	// Granular Updates
	func updateLocalization(versionId: String, description: String?, keywords: String?, promotionalText: String?, marketingURL: String?, supportURL: String?, whatsNew: String?) async throws
	func updateVersionAttributes(versionId: String, copyright: String?) async throws
	func updateReviewDetail(versionId: String, contactInfo: ContactInfo?, notes: String?) async throws

	// Fetching
	func fetchLocalization(versionId: String) async throws -> (description: String?, keywords: String?, promotionalText: String?, marketingURL: String?, supportURL: String?, whatsNew: String?)
	func fetchVersionAttributes(versionId: String) async throws -> (copyright: String?, releaseType: String?)
	func fetchReviewDetail(versionId: String) async throws -> (contactInfo: ContactInfo, notes: String?)
}

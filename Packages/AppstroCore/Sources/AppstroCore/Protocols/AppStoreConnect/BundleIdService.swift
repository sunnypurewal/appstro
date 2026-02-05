import Foundation

public protocol BundleIdService: Sendable {
	func deduceBundleIdPrefix(preferredPrefix: String?) async throws -> String?
	func registerBundleId(name: String, identifier: String) async throws -> String
	func findBundleIdRecordId(identifier: String) async throws -> String
}

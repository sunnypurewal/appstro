import Foundation

public struct AppDetails: Sendable {
	public let id: String
	public let name: String
	public let bundleId: String
	public let appStoreUrl: String
	public let publishedVersion: String?

	public init(id: String, name: String, bundleId: String, appStoreUrl: String, publishedVersion: String?) {
		self.id = id
		self.name = name
		self.bundleId = bundleId
		self.appStoreUrl = appStoreUrl
		self.publishedVersion = publishedVersion
	}
}

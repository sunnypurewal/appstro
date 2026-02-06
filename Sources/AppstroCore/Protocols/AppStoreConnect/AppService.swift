import Foundation

public protocol AppService: Sendable {
	func fetchAppDetails(query: AppQuery) async throws -> AppDetails?
	func listApps() async throws -> [AppInfo]
	func updateContentRights(appId: String, usesThirdPartyContent: Bool) async throws
}
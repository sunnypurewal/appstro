import AppstroCore
import Foundation
import AppStoreConnect_Swift_SDK

public final class ASCAppService: AppService {
	private let provider: any RequestProvider

	public init(provider: any RequestProvider) {
		self.provider = provider
	}

	public func fetchAppDetails(query: AppQuery) async throws -> AppDetails? {
		var parameters = APIEndpoint.V1.Apps.GetParameters()
		parameters.include = [.appStoreVersions]
		parameters.limitAppStoreVersions = 10
		parameters.limit = 200
		
		switch query.type {
		case .name:
			break
		case .bundleId(let bundleId):
			parameters.filterBundleID = [bundleId]
		}
		
		let endpoint = APIEndpoint.v1.apps.get(parameters: parameters)
		let response = try await provider.request(endpoint)
		
		let appData: AppStoreConnect_Swift_SDK.App?
		switch query.type {
		case .name(let name):
			appData = response.data.first { $0.attributes?.name?.localizedCaseInsensitiveCompare(name) == .orderedSame }
		case .bundleId:
			appData = response.data.first
		}
		
		guard let app = appData, let attributes = app.attributes else {
			return nil
		}
		
		let publishedVersion = findPublishedVersion(app: app, included: response.included ?? [])
		
		return AppDetails(
			id: app.id,
			name: attributes.name ?? "Unknown",
			bundleId: attributes.bundleID ?? "Unknown",
			appStoreUrl: "https://apps.apple.com/app/id\(app.id)",
			publishedVersion: publishedVersion
		)
	}

	public func listApps() async throws -> [AppstroCore.AppInfo] {
		let endpoint = APIEndpoint.v1.apps.get(parameters: .init(limit: 100))
		let response = try await provider.request(endpoint)
		return response.data.map { app in
			AppInfo(
				id: app.id,
				name: app.attributes?.name ?? "Unknown",
				bundleId: app.attributes?.bundleID ?? "Unknown"
			)
		}
	}

	public func updateContentRights(appId: String, usesThirdPartyContent: Bool) async throws {
		let attributes = AppUpdateRequest.Data.Attributes(contentRightsDeclaration: usesThirdPartyContent ? .usesThirdPartyContent : .doesNotUseThirdPartyContent)
		let updateRequest = AppUpdateRequest(data: .init(type: .apps, id: appId, attributes: attributes))
		_ = try await provider.request(APIEndpoint.v1.apps.id(appId).patch(updateRequest))
	}

	private func findPublishedVersion(app: AppStoreConnect_Swift_SDK.App, included: [AppStoreConnect_Swift_SDK.AppsResponse.IncludedItem]) -> String? {
		guard let versionIds = app.relationships?.appStoreVersions?.data?.map({ $0.id }) else {
			return nil
		}
		
		for versionId in versionIds {
			if let version = included.first(where: { 
				if case .appStoreVersion(let v) = $0 { return v.id == versionId }
				return false
			}) {
				if case .appStoreVersion(let v) = version, v.attributes?.appStoreState == .readyForSale {
					return v.attributes?.versionString
				}
			}
		}
		
		return nil
	}
}

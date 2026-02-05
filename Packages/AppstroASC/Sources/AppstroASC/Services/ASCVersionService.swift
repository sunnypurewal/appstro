import AppstroCore
import Foundation
import AppStoreConnect_Swift_SDK

public final class ASCVersionService: VersionService {
	private let provider: any RequestProvider
	
	public init(provider: any RequestProvider) {
		self.provider = provider
	}
	
	public func findDraftVersion(for appId: String) async throws -> DraftVersion? {
		var parameters = APIEndpoint.V1.Apps.WithID.AppStoreVersions.GetParameters()
		parameters.limit = 5
		let endpoint = APIEndpoint.v1.apps.id(appId).appStoreVersions.get(parameters: parameters)
		let response = try await provider.request(endpoint)
		
		if let draft = response.data.first(where: {
			guard let state = $0.attributes?.appStoreState else { return false }
			return state != AppStoreVersionState.readyForSale && state != AppStoreVersionState.replacedWithNewVersion
		}), let attributes = draft.attributes {
			return DraftVersion(
				version: attributes.versionString ?? "1.0",
				id: draft.id,
				state: mapState(attributes.appStoreState)
			)
		}
		return nil
	}
	
	public func fetchBuilds(appId: String, version: String? = nil) async throws -> [BuildInfo] {
		var parameters = APIEndpoint.V1.Builds.GetParameters()
		parameters.filterApp = [appId]
		// We don't filter by version because 'version' in ASC builds refers to CFBundleVersion (build number),
		// but we usually have the marketing version. It's safer to fetch the latest builds and find the right one.
		parameters.sort = [.minusuploadedDate]
		parameters.limit = 10
		
		let endpoint = APIEndpoint.v1.builds.get(parameters: parameters)
		let response = try await provider.request(endpoint)
		return response.data.map { build in
			BuildInfo(
				id: build.id,
				version: build.attributes?.version ?? "unknown",
				processingState: mapProcessingState(build.attributes?.processingState)
			)
		}
	}
	
	public func attachBuildToVersion(versionId: String, buildId: String) async throws {
		let relationshipData = AppStoreVersionBuildLinkageRequest.Data(type: .builds, id: buildId)
		let request = AppStoreVersionBuildLinkageRequest(data: relationshipData)
		let endpoint = APIEndpoint.v1.appStoreVersions.id(versionId).relationships.build.patch(request)
		_ = try await provider.request(endpoint)
	}

	public func createVersion(appId: String, versionString: String, platform: String) async throws -> DraftVersion {
		let attributes = AppStoreVersionCreateRequest.Data.Attributes(
			platform: platform == "ios" ? .ios : .macOs,
			versionString: versionString
		)
		let relationships = AppStoreVersionCreateRequest.Data.Relationships(
			app: AppStoreVersionCreateRequest.Data.Relationships.App(
				data: AppStoreVersionCreateRequest.Data.Relationships.App.Data(type: .apps, id: appId)
			)
		)
		let data = AppStoreVersionCreateRequest.Data(
			type: .appStoreVersions,
			attributes: attributes,
			relationships: relationships
		)
		let request = AppStoreVersionCreateRequest(data: data)
		let endpoint = APIEndpoint.v1.appStoreVersions.post(request)
		let response = try await provider.request(endpoint)
		
		let created = response.data
		return DraftVersion(
			version: created.attributes?.versionString ?? versionString,
			id: created.id,
			state: mapState(created.attributes?.appStoreState)
		)
	}

	public func fetchAttachedBuildId(versionId: String) async throws -> String? {
		let endpoint = APIEndpoint.v1.appStoreVersions.id(versionId).build.get()
		do {
			let response = try await provider.request(endpoint)
			return response.data.id
		} catch {
			// If no build is attached, this might throw or return empty data
			return nil
		}
	}
	
	private func mapState(_ state: AppStoreVersionState?) -> AppstroCore.AppVersionState {
		guard let state = state else { return .other }
		switch state {
			case .prepareForSubmission: return .prepareForSubmission
			case .readyForSale: return .readyForSale
			case .rejected: return .rejected
			case .developerRejected: return .developerRejected
			case .waitingForReview: return .waitingForReview
			case .inReview: return .inReview
			case .metadataRejected: return .metadataRejected
			default: return .other
		}
	}
	
	private func mapProcessingState(_ state: AppStoreConnect_Swift_SDK.Build.Attributes.ProcessingState?) -> BuildProcessingState {
		guard let state = state else { return .unknown }
		switch state {
			case .valid: return .valid
			case .invalid: return .invalid
			case .processing: return .processing
			case .failed: return .failed
		}
	}
}

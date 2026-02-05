import AppstroCore
import Foundation
import AppStoreConnect_Swift_SDK

public struct ASCAppClipService: AppClipService {
	private let provider: any RequestProvider

	public init(provider: any RequestProvider) {
		self.provider = provider
	}

	public func deleteDefaultExperience(id: String) async throws {
		let endpoint = APIEndpoint.v1.appClipDefaultExperiences.id(id).delete
		try await provider.request(endpoint)
	}

	public func fetchDefaultExperienceId(versionId: String) async throws -> String? {
		let endpoint = APIEndpoint.v1.appStoreVersions.id(versionId).appClipDefaultExperience.get()
		// If it doesn't exist, this might throw a 404 or return a response with nil data depending on SDK/API
		do {
			let response = try await provider.request(endpoint)
			return response.data.id
		} catch {
			// If it's a 404, we assume no experience exists
			return nil
		}
	}

	public func fetchAdvancedExperienceIds(appId: String) async throws -> [String] {
		let appClipsEndpoint = APIEndpoint.v1.apps.id(appId).appClips.get()
		let appClipsResponse = try await provider.request(appClipsEndpoint)
		
		var allAdvancedExperienceIds: [String] = []
		for appClip in appClipsResponse.data {
			let advancedEndpoint = APIEndpoint.v1.appClips.id(appClip.id).appClipAdvancedExperiences.get()
			let advancedResponse = try await provider.request(advancedEndpoint)
			allAdvancedExperienceIds.append(contentsOf: advancedResponse.data.map { $0.id })
		}
		return allAdvancedExperienceIds
	}

	public func deactivateAdvancedExperience(id: String) async throws {
		let body = AppClipAdvancedExperienceUpdateRequest(
			data: .init(
				type: .appClipAdvancedExperiences,
				id: id,
				attributes: .init(isRemoved: true)
			)
		)
		let endpoint = APIEndpoint.v1.appClipAdvancedExperiences.id(id).patch(body)
		_ = try await provider.request(endpoint)
	}
}

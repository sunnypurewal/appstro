import AppstroCore
import Foundation
import AppStoreConnect_Swift_SDK

public final class ASCMetadataService: MetadataService {
	private let provider: any RequestProvider

	public init(provider: any RequestProvider) {
		self.provider = provider
	}

	public func updateMetadata(versionId: String, metadata: GeneratedMetadata, urls: (support: String, marketing: String), copyright: String, contactInfo: ContactInfo) async throws {
		// 1. Update Localization
		let locEndpoint = APIEndpoint.v1.appStoreVersions.id(versionId).appStoreVersionLocalizations.get()
		let locResponse = try await provider.request(locEndpoint)
		guard let localization = locResponse.data.first else {
			throw AppStoreConnectError.apiError("No localizations found for this version.")
		}

		let locAttributes = AppStoreVersionLocalizationUpdateRequest.Data.Attributes(
			description: metadata.description,
			keywords: metadata.keywords,
			marketingURL: URL(string: urls.marketing),
			promotionalText: metadata.promotionalText,
			supportURL: URL(string: urls.support),
			whatsNew: metadata.whatsNew
		)
		let locUpdate = AppStoreVersionLocalizationUpdateRequest(data: .init(type: .appStoreVersionLocalizations, id: localization.id, attributes: locAttributes))
		_ = try await provider.request(APIEndpoint.v1.appStoreVersionLocalizations.id(localization.id).patch(locUpdate))

		// 2. Update Version Attributes (Copyright & Release Type)
		let versionAttributes = AppStoreVersionUpdateRequest.Data.Attributes(
			copyright: copyright,
			releaseType: .afterApproval
		)
		let versionUpdate = AppStoreVersionUpdateRequest(data: .init(type: .appStoreVersions, id: versionId, attributes: versionAttributes))
		_ = try await provider.request(APIEndpoint.v1.appStoreVersions.id(versionId).patch(versionUpdate))

		// 3. Update Review Details
		var reviewParams = APIEndpoint.V1.AppStoreVersions.WithID.GetParameters()
		reviewParams.include = [.appStoreReviewDetail]
		let versionEndpoint = APIEndpoint.v1.appStoreVersions.id(versionId).get(parameters: reviewParams)
		let versionResponse = try await provider.request(versionEndpoint)
		
		let existingReviewDetailId = versionResponse.included?.compactMap { item -> String? in
			if case .appStoreReviewDetail(let detail) = item { return detail.id }
			return nil
		}.first

		if let reviewId = existingReviewDetailId {
			let reviewAttributes = AppStoreReviewDetailUpdateRequest.Data.Attributes(
				contactFirstName: contactInfo.firstName,
				contactLastName: contactInfo.lastName,
				contactPhone: contactInfo.phone,
				contactEmail: contactInfo.email,
				isDemoAccountRequired: false,
				notes: metadata.reviewNotes
			)
			let reviewUpdate = AppStoreReviewDetailUpdateRequest(data: .init(type: .appStoreReviewDetails, id: reviewId, attributes: reviewAttributes))
			_ = try await provider.request(APIEndpoint.v1.appStoreReviewDetails.id(reviewId).patch(reviewUpdate))
		} else {
			let relData = AppStoreReviewDetailCreateRequest.Data.Relationships.AppStoreVersion.Data(type: .appStoreVersions, id: versionId)
			let rel = AppStoreReviewDetailCreateRequest.Data.Relationships(appStoreVersion: .init(data: relData))
			let createAttributes = AppStoreReviewDetailCreateRequest.Data.Attributes(
				contactFirstName: contactInfo.firstName,
				contactLastName: contactInfo.lastName,
				contactPhone: contactInfo.phone,
				contactEmail: contactInfo.email,
				isDemoAccountRequired: false,
				notes: metadata.reviewNotes
			)
			let createRequest = AppStoreReviewDetailCreateRequest(data: .init(type: .appStoreReviewDetails, attributes: createAttributes, relationships: rel))
			_ = try await provider.request(APIEndpoint.v1.appStoreReviewDetails.post(createRequest))
		}
	}

	public func updatePrivacyPolicy(appId: String, url: URL) async throws {
		let appInfosEndpoint = APIEndpoint.v1.apps.id(appId).appInfos.get()
		let response = try await provider.request(appInfosEndpoint)
		
		guard let appInfoId = response.data.first?.id else {
			throw AppStoreConnectError.apiError("No App Info found for app \(appId)")
		}

		let locEndpoint = APIEndpoint.v1.appInfos.id(appInfoId).appInfoLocalizations.get()
		let locResponse = try await provider.request(locEndpoint)
		
		for localization in locResponse.data {
			let attributes = AppInfoLocalizationUpdateRequest.Data.Attributes(privacyPolicyURL: url.absoluteString)
			let updateRequest = AppInfoLocalizationUpdateRequest(data: .init(type: .appInfoLocalizations, id: localization.id, attributes: attributes))
			_ = try await provider.request(APIEndpoint.v1.appInfoLocalizations.id(localization.id).patch(updateRequest))
		}
	}

	public func updateLocalization(versionId: String, description: String?, keywords: String?, promotionalText: String?, marketingURL: String?, supportURL: String?, whatsNew: String?) async throws {
		let locEndpoint = APIEndpoint.v1.appStoreVersions.id(versionId).appStoreVersionLocalizations.get()
		let locResponse = try await provider.request(locEndpoint)
		guard let localization = locResponse.data.first else {
			throw AppStoreConnectError.apiError("No localizations found for this version.")
		}

		let locAttributes = AppStoreVersionLocalizationUpdateRequest.Data.Attributes(
			description: description,
			keywords: keywords,
			marketingURL: marketingURL.flatMap(URL.init),
			promotionalText: promotionalText,
			supportURL: supportURL.flatMap(URL.init),
			whatsNew: whatsNew
		)
		let locUpdate = AppStoreVersionLocalizationUpdateRequest(data: .init(type: .appStoreVersionLocalizations, id: localization.id, attributes: locAttributes))
		_ = try await provider.request(APIEndpoint.v1.appStoreVersionLocalizations.id(localization.id).patch(locUpdate))
	}

	public func updateVersionAttributes(versionId: String, copyright: String?) async throws {
		let versionAttributes = AppStoreVersionUpdateRequest.Data.Attributes(
			copyright: copyright
		)
		let versionUpdate = AppStoreVersionUpdateRequest(data: .init(type: .appStoreVersions, id: versionId, attributes: versionAttributes))
		_ = try await provider.request(APIEndpoint.v1.appStoreVersions.id(versionId).patch(versionUpdate))
	}

	public func updateReviewDetail(versionId: String, contactInfo: ContactInfo?, notes: String?) async throws {
		var reviewParams = APIEndpoint.V1.AppStoreVersions.WithID.GetParameters()
		reviewParams.include = [.appStoreReviewDetail]
		let versionEndpoint = APIEndpoint.v1.appStoreVersions.id(versionId).get(parameters: reviewParams)
		let versionResponse = try await provider.request(versionEndpoint)
		
		let existingReviewDetailId = versionResponse.included?.compactMap { item -> String? in
			if case .appStoreReviewDetail(let detail) = item { return detail.id }
			return nil
		}.first

		if let reviewId = existingReviewDetailId {
			let reviewAttributes = AppStoreReviewDetailUpdateRequest.Data.Attributes(
				contactFirstName: contactInfo?.firstName,
				contactLastName: contactInfo?.lastName,
				contactPhone: contactInfo?.phone,
				contactEmail: contactInfo?.email,
				isDemoAccountRequired: false,
				notes: notes
			)
			let reviewUpdate = AppStoreReviewDetailUpdateRequest(data: .init(type: .appStoreReviewDetails, id: reviewId, attributes: reviewAttributes))
			_ = try await provider.request(APIEndpoint.v1.appStoreReviewDetails.id(reviewId).patch(reviewUpdate))
		} else {
			let relData = AppStoreReviewDetailCreateRequest.Data.Relationships.AppStoreVersion.Data(type: .appStoreVersions, id: versionId)
			let rel = AppStoreReviewDetailCreateRequest.Data.Relationships(appStoreVersion: .init(data: relData))
			let createAttributes = AppStoreReviewDetailCreateRequest.Data.Attributes(
				contactFirstName: contactInfo?.firstName,
				contactLastName: contactInfo?.lastName,
				contactPhone: contactInfo?.phone,
				contactEmail: contactInfo?.email,
				isDemoAccountRequired: false,
				notes: notes
			)
			let createRequest = AppStoreReviewDetailCreateRequest(data: .init(type: .appStoreReviewDetails, attributes: createAttributes, relationships: rel))
			_ = try await provider.request(APIEndpoint.v1.appStoreReviewDetails.post(createRequest))
		}
	}

	public func fetchLocalization(versionId: String) async throws -> (description: String?, keywords: String?, promotionalText: String?, marketingURL: String?, supportURL: String?, whatsNew: String?) {
		let locEndpoint = APIEndpoint.v1.appStoreVersions.id(versionId).appStoreVersionLocalizations.get()
		let locResponse = try await provider.request(locEndpoint)
		guard let localization = locResponse.data.first else {
			return (nil, nil, nil, nil, nil, nil)
		}
		let attrs = localization.attributes
		return (
			description: attrs?.description,
			keywords: attrs?.keywords,
			promotionalText: attrs?.promotionalText,
			marketingURL: attrs?.marketingURL?.absoluteString,
			supportURL: attrs?.supportURL?.absoluteString,
			whatsNew: attrs?.whatsNew
		)
	}

	public func fetchVersionAttributes(versionId: String) async throws -> (copyright: String?, releaseType: String?) {
		let versionEndpoint = APIEndpoint.v1.appStoreVersions.id(versionId).get()
		let response = try await provider.request(versionEndpoint)
		let attrs = response.data.attributes
		return (
			copyright: attrs?.copyright,
			releaseType: attrs?.releaseType?.rawValue
		)
	}

	public func fetchReviewDetail(versionId: String) async throws -> (contactInfo: ContactInfo, notes: String?) {
		var reviewParams = APIEndpoint.V1.AppStoreVersions.WithID.GetParameters()
		reviewParams.include = [.appStoreReviewDetail]
		let versionEndpoint = APIEndpoint.v1.appStoreVersions.id(versionId).get(parameters: reviewParams)
		let versionResponse = try await provider.request(versionEndpoint)
		
		let detail = versionResponse.included?.compactMap { item -> AppStoreReviewDetail? in
			if case .appStoreReviewDetail(let detail) = item { return detail }
			return nil
		}.first

		let contactInfo = ContactInfo(
			firstName: detail?.attributes?.contactFirstName,
			lastName: detail?.attributes?.contactLastName,
			email: detail?.attributes?.contactEmail,
			phone: detail?.attributes?.contactPhone
		)
		return (contactInfo: contactInfo, notes: detail?.attributes?.notes)
	}
}

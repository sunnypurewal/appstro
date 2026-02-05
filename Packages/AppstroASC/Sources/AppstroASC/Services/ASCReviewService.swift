import AppstroCore
import Foundation
import AppStoreConnect_Swift_SDK
import CryptoKit

public final class ASCReviewService: ReviewService {
	private let provider: any RequestProvider
	private let appService: any AppService

	public init(provider: any RequestProvider, appService: any AppService) {
		self.provider = provider
		self.appService = appService
	}

	public func fetchContactInfo() async throws -> ContactInfo {
		if let existing = try? await fetchExistingReviewDetail() {
			return existing
		}

		let usersEndpoint = APIEndpoint.v1.users.get(parameters: .init(limit: 1))
		let userResponse = try await provider.request(usersEndpoint)
		
		if let user = userResponse.data.first?.attributes {
			return ContactInfo(
				firstName: user.firstName,
				lastName: user.lastName,
				email: user.username,
				phone: nil
			)
		}
		
		return ContactInfo()
	}

	public func submitForReview(appId: String, versionId: String) async throws {
		// 1. Check for all existing review submissions to find if our version is already included
		let params = APIEndpoint.V1.ReviewSubmissions.GetParameters(
			filterApp: [appId],
			limit: 50
		)
		let submissionsEndpoint = APIEndpoint.v1.reviewSubmissions.get(parameters: params)
		let submissionsResponse = try await provider.request(submissionsEndpoint)
		
		var targetSubmissionId: String? = nil
		
		// 2. Look for a submission that already contains our version
		for submission in submissionsResponse.data {
			var itemsParams = APIEndpoint.V1.ReviewSubmissions.WithID.Items.GetParameters()
			itemsParams.limit = 50
			let itemsEndpoint = APIEndpoint.v1.reviewSubmissions.id(submission.id).items.get(parameters: itemsParams)
			let itemsResponse = try await provider.request(itemsEndpoint)
			
			let containsVersion = itemsResponse.data.contains { item in
				// We check the version relationship. If it's missing, we might need to include it in the request, 
				// but usually the ID is present in the relationship data.
				item.relationships?.appStoreVersion?.data?.id == versionId
			}
			
			if containsVersion {
				targetSubmissionId = submission.id
				break
			}
		}
		
		// 3. If no submission contains our version, find or create a READY_FOR_REVIEW one
		let sid: String
		if let existingId = targetSubmissionId {
			sid = existingId
		} else {
			let readySubmission = submissionsResponse.data.first { $0.attributes?.state == .readyForReview }
			
			if let existing = readySubmission {
				sid = existing.id
			} else {
				// Create new submission container
				let appRel = ReviewSubmissionCreateRequest.Data.Relationships.App(data: .init(type: .apps, id: appId))
				let relationships = ReviewSubmissionCreateRequest.Data.Relationships(app: appRel)
				
				let submissionAttributes = ReviewSubmissionCreateRequest.Data.Attributes(platform: .ios)
				let submissionCreateRequest = ReviewSubmissionCreateRequest(data: .init(type: .reviewSubmissions, attributes: submissionAttributes, relationships: relationships))
				let submissionEndpoint = APIEndpoint.v1.reviewSubmissions.post(submissionCreateRequest)
				let submission = try await provider.request(submissionEndpoint)
				sid = submission.data.id
			}
			
			// Add version to the submission
			let itemAttributes = ReviewSubmissionItemCreateRequest.Data.Relationships(
				reviewSubmission: .init(data: .init(type: .reviewSubmissions, id: sid)),
				appStoreVersion: .init(data: .init(type: .appStoreVersions, id: versionId))
			)
			let itemCreateRequest = ReviewSubmissionItemCreateRequest(data: .init(type: .reviewSubmissionItems, relationships: itemAttributes))
			let itemEndpoint = APIEndpoint.v1.reviewSubmissionItems.post(itemCreateRequest)
			
			do {
				_ = try await provider.request(itemEndpoint)
			} catch {
				// Ignore 409 Conflict if already attached (though we checked above, it might be in a different submission state)
				if let apiError = error as? AppStoreConnectError, case .detailedApiError(_, let statusCode, _) = apiError, statusCode == 409 {
					// Already attached elsewhere or in this one
				} else {
					throw error
				}
			}
		}
		
		// 4. Submit the container
		let updateAttributes = ReviewSubmissionUpdateRequest.Data.Attributes(isSubmitted: true)
		let updateRequest = ReviewSubmissionUpdateRequest(data: .init(type: .reviewSubmissions, id: sid, attributes: updateAttributes))
		let updateEndpoint = APIEndpoint.v1.reviewSubmissions.id(sid).patch(updateRequest)
		
		_ = try await provider.request(updateEndpoint)
	}

	public func cancelReviewSubmission(appId: String) async throws {
		let states: [APIEndpoint.V1.ReviewSubmissions.GetParameters.FilterState] = [.waitingForReview, .inReview, .readyForReview]
		let params = APIEndpoint.V1.ReviewSubmissions.GetParameters(filterState: states, filterApp: [appId])
		let endpoint = APIEndpoint.v1.reviewSubmissions.get(parameters: params)
		let response = try await provider.request(endpoint)
		
		for submission in response.data {
			let updateAttributes = ReviewSubmissionUpdateRequest.Data.Attributes(isSubmitted: false, isCanceled: true)
			let updateRequest = ReviewSubmissionUpdateRequest(data: .init(type: .reviewSubmissions, id: submission.id, attributes: updateAttributes))
			let updateEndpoint = APIEndpoint.v1.reviewSubmissions.id(submission.id).patch(updateRequest)
			_ = try await provider.request(updateEndpoint)
		}
	}

	public func uploadReviewAttachment(versionId: String, fileURL: URL) async throws {
		// 1. Ensure review detail exists
		let detailId: String
		var params = APIEndpoint.V1.AppStoreVersions.WithID.GetParameters()
		params.include = [.appStoreReviewDetail]
		let versionEndpoint = APIEndpoint.v1.appStoreVersions.id(versionId).get(parameters: params)
		let versionResponse = try await provider.request(versionEndpoint)
		
		let existingDetail = versionResponse.included?.compactMap { item -> AppStoreReviewDetail? in
			if case .appStoreReviewDetail(let detail) = item { return detail }
			return nil
		}.first
		
		if let existing = existingDetail {
			detailId = existing.id
		} else {
			let rel = AppStoreReviewDetailCreateRequest.Data.Relationships(
				appStoreVersion: .init(data: .init(type: .appStoreVersions, id: versionId))
			)
			let createRequest = AppStoreReviewDetailCreateRequest(data: .init(type: .appStoreReviewDetails, relationships: rel))
			let createEndpoint = APIEndpoint.v1.appStoreReviewDetails.post(createRequest)
			let newDetail = try await provider.request(createEndpoint)
			detailId = newDetail.data.id
		}
		
		// 2. Reserve attachment
		let fileData = try Data(contentsOf: fileURL)
		let fileName = fileURL.lastPathComponent
		let attributes = AppStoreReviewAttachmentCreateRequest.Data.Attributes(fileSize: fileData.count, fileName: fileName)
		let rel = AppStoreReviewAttachmentCreateRequest.Data.Relationships(
			appStoreReviewDetail: .init(data: .init(type: .appStoreReviewDetails, id: detailId))
		)
		let reserveRequest = AppStoreReviewAttachmentCreateRequest(data: .init(type: .appStoreReviewAttachments, attributes: attributes, relationships: rel))
		let reserveEndpoint = APIEndpoint.v1.appStoreReviewAttachments.post(reserveRequest)
		let reservation = try await provider.request(reserveEndpoint)
		
		// 3. Upload bits
		guard let operations = reservation.data.attributes?.uploadOperations else {
			throw AppStoreConnectError.apiError("Missing upload operations for \(fileName)")
		}
		
		for op in operations {
			guard let urlStr = op.url, let url = URL(string: urlStr) else { continue }
			var request = URLRequest(url: url)
			request.httpMethod = op.method ?? "PUT"
			op.requestHeaders?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.name ?? "") }
			
			let start = op.offset ?? 0
			let length = op.length ?? 0
			let end = start + length
			let chunk = fileData.subdata(in: start..<end)
			
			let (_, response) = try await URLSession.shared.upload(for: request, from: chunk)
			guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
				throw AppStoreConnectError.apiError("Binary upload failed for \(fileName)")
			}
		}
		
		// 4. Commit
		let checksum = Insecure.MD5.hash(data: fileData).map { String(format: "%02hhx", $0) }.joined()
		let updateAttributes = AppStoreReviewAttachmentUpdateRequest.Data.Attributes(sourceFileChecksum: checksum, isUploaded: true)
		let updateRequest = AppStoreReviewAttachmentUpdateRequest(data: .init(type: .appStoreReviewAttachments, id: reservation.data.id, attributes: updateAttributes))
		let updateEndpoint = APIEndpoint.v1.appStoreReviewAttachments.id(reservation.data.id).patch(updateRequest)
		_ = try await provider.request(updateEndpoint)
		
		// 5. Poll
		var isProcessed = false
		var attempts = 0
		let maxAttempts = 30
		
		while !isProcessed && attempts < maxAttempts {
			attempts += 1
			try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
			
			let pollEndpoint = APIEndpoint.v1.appStoreReviewAttachments.id(reservation.data.id).get()
			let status = try await provider.request(pollEndpoint)
			
			if let state = status.data.attributes?.assetDeliveryState {
				switch state.state {
				case .complete:
					isProcessed = true
				case .failed:
					let details = state.errors?.map { "[\($0.code ?? "no-code")] \($0.description ?? "no-description")" }.joined(separator: "; ") ?? "Unknown Apple processing error"
					throw AppStoreConnectError.apiError("Processing failed for \(fileName): \(details)")
				default:
					break
				}
			}
		}
		
		if !isProcessed {
			throw AppStoreConnectError.apiError("Timeout waiting for \(fileName) to process at Apple.")
		}
	}

	public func getDeveloperEmailDomain() async throws -> String {
		let info = try await fetchContactInfo()
		if let email = info.email {
			let parts = email.split(separator: "@")
			if parts.count == 2 {
				return String(parts[1])
			}
		}
		return "example.com"
	}

	public func getTeamName() async throws -> String {
		let info = try await fetchContactInfo()
		if let first = info.firstName, let last = info.lastName {
			return "\(first) \(last)"
		}
		return "Developer"
	}

	private func fetchExistingReviewDetail() async throws -> ContactInfo? {
		let apps = try await appService.listApps()
		
		for app in apps {
			var params = APIEndpoint.V1.Apps.WithID.AppStoreVersions.GetParameters()
			params.include = [.appStoreReviewDetail]
			params.limit = 5
			
			let endpoint = APIEndpoint.v1.apps.id(app.id).appStoreVersions.get(parameters: params)
			let response = try await provider.request(endpoint)
			
			let reviewDetail = response.included?.compactMap { item -> AppStoreReviewDetail? in
				if case .appStoreReviewDetail(let detail) = item { return detail }
				return nil
			}.first { detail in
				return detail.attributes?.contactPhone != nil && detail.attributes?.contactEmail != nil
			}
			
			if let detail = reviewDetail, let attr = detail.attributes {
				return ContactInfo(
					firstName: attr.contactFirstName,
					lastName: attr.contactLastName,
					email: attr.contactEmail,
					phone: attr.contactPhone
				)
			}
		}
		return nil
	}
}

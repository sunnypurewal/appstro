import AppstroCore
import Foundation
import AppStoreConnect_Swift_SDK

public final class ASCCertificateService: CertificateService {
	private let provider: any RequestProvider

	public init(provider: any RequestProvider) {
		self.provider = provider
	}

	public func findDistributionCertificateId() async throws -> String {
		let endpoint = APIEndpoint.v1.certificates.get(parameters: .init(filterCertificateType: [], limit: 10))
		_ = try await provider.request(endpoint)
		
		// This is a placeholder since the original code also had a placeholder/error
		throw AppStoreConnectError.apiError("Certificate fetching not implemented correctly yet.")
	}

	public func createProvisioningProfile(name: String, bundleIdRecordId: String, certificateId: String) async throws -> Data {
		let attributes = ProfileCreateRequest.Data.Attributes(
			name: name,
			profileType: .iosAppStore
		)
		
		let bundleIdRel = ProfileCreateRequest.Data.Relationships.BundleID(
			data: .init(type: .bundleIDs, id: bundleIdRecordId)
		)
		let certRel = ProfileCreateRequest.Data.Relationships.Certificates(
			data: [.init(type: .certificates, id: certificateId)]
		)
		
		let relationships = ProfileCreateRequest.Data.Relationships(
			bundleID: bundleIdRel,
			certificates: certRel
		)
		
		let createRequest = ProfileCreateRequest(data: .init(type: .profiles, attributes: attributes, relationships: relationships))
		let endpoint = APIEndpoint.v1.profiles.post(createRequest)
		let response = try await provider.request(endpoint)
		
		guard let contentBase64 = response.data.attributes?.profileContent,
			  let data = Data(base64Encoded: contentBase64) else {
			throw AppStoreConnectError.apiError("Failed to download provisioning profile content.")
		}
		
		return data
	}
}

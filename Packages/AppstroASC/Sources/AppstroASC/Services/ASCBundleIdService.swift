import AppstroCore
import Foundation
import AppStoreConnect_Swift_SDK

public final class ASCBundleIdService: BundleIdService {
	private let provider: any RequestProvider

	public init(provider: any RequestProvider) {
		self.provider = provider
	}

	public func deduceBundleIdPrefix(preferredPrefix: String?) async throws -> String? {
		if let preferredPrefix = preferredPrefix {
			return preferredPrefix
		}

		// 1. Try historical Bundle IDs
		let bundleIdsEndpoint = APIEndpoint.v1.bundleIDs.get(parameters: .init(limit: 200))
		let bundleResponse = try await provider.request(bundleIdsEndpoint)
		
		let identifiers = bundleResponse.data.compactMap { $0.attributes?.identifier }
		if let prefix = findMostFrequentPrefix(identifiers: identifiers) {
			return prefix
		}
		
		// 2. Try email domain fallback
		let usersEndpoint = APIEndpoint.v1.users.get(parameters: .init(limit: 10))
		let userResponse = try await provider.request(usersEndpoint)
		
		if let email = userResponse.data.first?.attributes?.username {
			let parts = email.split(separator: "@")
			if parts.count == 2 {
				let domain = String(parts[1])
				let genericProviders = ["gmail.com", "icloud.com", "outlook.com", "yahoo.com", "me.com", "hotmail.com"]
				if !genericProviders.contains(domain.lowercased()) {
					let domainParts = domain.split(separator: ".")
					return domainParts.reversed().joined(separator: ".")
				}
			}
		}
		
		return nil
	}

	public func registerBundleId(name: String, identifier: String) async throws -> String {
		// 1. Check if identifier already exists
		let filterEndpoint = APIEndpoint.v1.bundleIDs.get(parameters: .init(filterIdentifier: [identifier]))
		let existingBundleResponse = try await provider.request(filterEndpoint)
		
		if let existing = existingBundleResponse.data.first {
			return existing.id
		}
		
		// 2. Register if it doesn't exist
		let attributes = BundleIDCreateRequest.Data.Attributes(name: name, platform: .ios, identifier: identifier)
		let data = BundleIDCreateRequest.Data(type: .bundleIDs, attributes: attributes)
		let registerRequest = BundleIDCreateRequest(data: data)
		let endpoint = APIEndpoint.v1.bundleIDs.post(registerRequest)
		let newBundle = try await provider.request(endpoint)
		return newBundle.data.id
	}

	public func findBundleIdRecordId(identifier: String) async throws -> String {
		let endpoint = APIEndpoint.v1.bundleIDs.get(parameters: .init(filterIdentifier: [identifier]))
		let response = try await provider.request(endpoint)
		
		guard let record = response.data.first else {
			throw AppStoreConnectError.apiError("Bundle ID '\(identifier)' not found on App Store Connect.")
		}
		
		return record.id
	}

	private func findMostFrequentPrefix(identifiers: [String]) -> String? {
		var counts: [String: Int] = [:]
		for id in identifiers {
			let parts = id.split(separator: ".")
			if parts.count > 1 {
				let prefix = parts.dropLast().joined(separator: ".")
				counts[prefix, default: 0] += 1
			}
		}
		return counts.max(by: { $0.value < $1.value })?.key
	}
}

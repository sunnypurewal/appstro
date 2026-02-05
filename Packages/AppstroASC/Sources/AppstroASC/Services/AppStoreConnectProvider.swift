import AppstroCore
import Foundation
@preconcurrency import AppStoreConnect_Swift_SDK

public protocol RequestProvider: Sendable {
	func request<T: Decodable>(_ endpoint: Request<T>) async throws -> T
	func request(_ endpoint: Request<Void>) async throws
}

extension APIProvider: @retroactive @unchecked Sendable, RequestProvider {}

public final class AppStoreConnectProvider: Sendable {
	public let requestProvider: any RequestProvider

	public init(requestProvider: any RequestProvider) {
		self.requestProvider = ErrorMappingRequestProvider(inner: requestProvider)
	}

	public convenience init(issuerId: String, keyId: String, privateKey: String) throws {
		let sanitizedKey = privateKey
			.replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
			.replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
			.replacingOccurrences(of: "\n", with: "")
			.replacingOccurrences(of: "\r", with: "")
			.trimmingCharacters(in: .whitespacesAndNewlines)
			
		let configuration = try APIConfiguration(issuerID: issuerId, privateKeyID: keyId, privateKey: sanitizedKey)
		let provider = APIProvider(configuration: configuration)
		self.init(requestProvider: provider)
	}
}

private struct ErrorMappingRequestProvider: RequestProvider {
	let inner: any RequestProvider

	func request<T: Decodable>(_ endpoint: Request<T>) async throws -> T {
		do {
			return try await inner.request(endpoint)
		} catch {
			throw mapError(error)
		}
	}

	func request(_ endpoint: Request<Void>) async throws {
		do {
			try await inner.request(endpoint)
		} catch {
			throw mapError(error)
		}
	}

	private func mapError(_ error: Error) -> Error {
		if let apiError = error as? APIProvider.Error {
			switch apiError {
			case .requestFailure(let statusCode, let errorResponse, _):
				let messages = errorResponse?.errors?.map { $0.detail ?? $0.title } ?? []
				return AppStoreConnectError.detailedApiError(
					title: "App Store Connect API Error",
					statusCode: statusCode,
					errors: messages
				)
			default:
				return error
			}
		}
		return error
	}
}


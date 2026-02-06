import Foundation
import AppStoreConnect_Swift_SDK
@testable import AppstroASC

final class MockRequestProvider: RequestProvider, @unchecked Sendable {
    var responses: [Any] = []
    var error: Error?
    var lastEndpoint: Any?
    var callCount = 0

    func request<T: Decodable>(_ endpoint: Request<T>) async throws -> T {
        lastEndpoint = endpoint
        callCount += 1
        if let error = error {
            throw error
        }
        if !responses.isEmpty {
            let response = responses.removeFirst()
            if let response = response as? T {
                return response
            }
        }
        throw AppStoreConnectError.invalidResponse
    }

    func request(_ endpoint: Request<Void>) async throws {
        lastEndpoint = endpoint
        callCount += 1
        if let error = error {
            throw error
        }
    }
}
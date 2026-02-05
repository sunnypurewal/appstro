import AppstroCore
import Foundation

public enum AppStoreConnectError: Error, LocalizedError {
	case invalidResponse
	case apiError(String)
	case detailedApiError(title: String, statusCode: Int, errors: [String])
	case missingCredentials
	case invalidPrivateKey

	public var errorDescription: String? {
		switch self {
		case .invalidResponse:
			return "Invalid response from App Store Connect."
		case .apiError(let message):
			return message
		case .detailedApiError(let title, let statusCode, let errors):
			if errors.isEmpty {
				return "\(title) (Status \(statusCode))"
			}
			return "\(title) (Status \(statusCode))\n\nAssociated errors:\n" + errors.map { "- \($0)" }.joined(separator: "\n")
		case .missingCredentials:
			return "Missing App Store Connect credentials."
		case .invalidPrivateKey:
			return "Invalid private key for App Store Connect."
		}
	}
}

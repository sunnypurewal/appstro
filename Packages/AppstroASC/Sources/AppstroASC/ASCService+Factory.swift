import AppstroCore
import Foundation

public enum ASCServiceFactory {
	public static func makeService(bezelService: any BezelService) throws -> any AppStoreConnectService {
		guard let issuerId = ProcessInfo.processInfo.environment["APPSTORE_ISSUER_ID"],
			  let keyId = ProcessInfo.processInfo.environment["APPSTORE_KEY_ID"],
			  let privateKey = ProcessInfo.processInfo.environment["APPSTORE_PRIVATE_KEY"] else {
			throw NSError(domain: "ASCServiceFactory", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing App Store Connect credentials in environment variables."])
		}
		
		return try ASCAppStoreConnectService(
			issuerId: issuerId, 
			keyId: keyId, 
			privateKey: privateKey, 
			bezelService: bezelService
		)
	}
}

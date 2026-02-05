import Foundation

public protocol CertificateService: Sendable {
	func findDistributionCertificateId() async throws -> String
	func createProvisioningProfile(name: String, bundleIdRecordId: String, certificateId: String) async throws -> Data
}

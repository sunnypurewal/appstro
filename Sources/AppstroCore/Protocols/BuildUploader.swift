import Foundation

public protocol BuildUploader: Sendable {
    func uploadIPA(ipaURL: URL, issuerId: String, keyId: String, privateKey: String) async throws
}

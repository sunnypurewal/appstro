import ArgumentParser
import Foundation

struct Privacy: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "privacy",
        abstract: "Update the app's privacy policy and data collection info."
    )

    @Option(name: .long, help: "The URL of the privacy policy.")
    var url: String?

    func run() async throws {
        guard let issuerId = ProcessInfo.processInfo.environment["APPSTORE_ISSUER_ID"],
              let keyId = ProcessInfo.processInfo.environment["APPSTORE_KEY_ID"],
              let privateKey = ProcessInfo.processInfo.environment["APPSTORE_PRIVATE_KEY"] else {
            print("❌ Error: Missing App Store Connect credentials.")
            return
        }

        let service = try AppStoreConnectService(issuerId: issuerId, keyId: keyId, privateKey: privateKey)
        
        print("🔍 Checking draft version...")
        guard let draft = try await service.findLatestDraftVersion() else {
            print("❌ No app version in 'Prepare for Submission' state found.")
            return
        }

        let defaultURL = "https://example.com/privacy"
        let privacyURL = url ?? defaultURL
        
        guard let url = URL(string: privacyURL) else {
            print("❌ Invalid URL: \(privacyURL)")
            return
        }

        print("🚀 Updating Privacy Policy URL to: \(url.absoluteString)...")
        try await service.updatePrivacyPolicy(appId: draft.app.id, url: url)
        print("✅ Privacy Policy updated successfully!")
    }
}

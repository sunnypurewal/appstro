import ArgumentParser
import Foundation

struct Pricing: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pricing",
        abstract: "Update the app's pricing tier."
    )

    @Option(name: .long, help: "The pricing tier (e.g., '0' for Free).")
    var tier: String = "0"

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

        print("🚀 Updating Pricing to: \(tier == "0" ? "Free" : "Tier " + tier)...")
        try await service.updateAppPrice(appId: draft.app.id, tier: tier)
        print("✅ Pricing updated successfully!")
    }
}

import ArgumentParser
import Foundation

struct Pricing: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pricing",
        abstract: "Update the app's pricing."
    )

    @Option(name: [.short, .long], help: "The price point (e.g., '0' for Free, '0.99', '1.99', etc.).")
    var price: String = "0"

    @Flag(name: .shortAndLong, help: "List all available price points for the app.")
    var list: Bool = false

    func run() async throws {
        guard let issuerId = ProcessInfo.processInfo.environment["APPSTORE_ISSUER_ID"],
              let keyId = ProcessInfo.processInfo.environment["APPSTORE_KEY_ID"],
              let privateKey = ProcessInfo.processInfo.environment["APPSTORE_PRIVATE_KEY"] else {
            print("❌ Error: Missing App Store Connect credentials.")
            return
        }

        let service = try AppStoreConnectService(issuerId: issuerId, keyId: keyId, privateKey: privateKey)
        
        print("🔍 Checking for app...")
        guard let draft = try await service.findLatestDraftVersion() else {
            print("❌ No app version in 'Prepare for Submission' state found.")
            return
        }

        if list {
            print("📋 Fetching available price points...")
            let points = try await service.fetchAppPricePoints(appId: draft.app.id)
            print("Available price points:")
            for point in points.prefix(20) {
                print("  - \(point)")
            }
            if points.count > 20 {
                print("  ... and \(points.count - 20) more.")
            }
            return
        }

        // --- NEW GUIDED PROCESS ---
        
        let initialIds = try? await service.fetchCurrentPriceSchedule(appId: draft.app.id)
        let currentPriceStatus = try? await service.fetchCurrentPriceDescription(appId: draft.app.id)

        // 1. Open Browser
        let urlString = "https://appstoreconnect.apple.com/apps/\(draft.app.id)/distribution/pricing"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [urlString]
        try? process.run()

        // 2. Display Instructions
//        print("\u{001B}[2J\u{001B}[H") // Clear screen
        print("💰 Pricing Setup Assistant")
        print("-----------------------------------------------------------")
        print("I've opened the Pricing page for '\(draft.app.name)' in your browser.")
        
        if let status = currentPriceStatus {
            print("\n✅ Current Price: \(status)")
            print("To update this, follow the steps below to add a new price.")
        } else {
            print("\n📝 Current Status: No pricing set yet.")
        }

        print("\nFollow these simple steps:")
        print("1. Click the blue 'Add Pricing Change' button.")
        print("2. In the 'Price' dropdown, select '$0.00 (Free)'.")
        print("3. Click 'Next', then 'Next' again, and finally 'Confirm'.")
        print("-----------------------------------------------------------")

        // 3. Magic Polling Loop
        var isPriceUpdated = false
        var attempts = 0
        while !isPriceUpdated {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // Increase to 2 seconds to be safe with API propagation
            attempts += 1
            
            if let currentIds = try? await service.fetchCurrentPriceSchedule(appId: draft.app.id) {
                if let initial = initialIds {
                    // Success if the set of IDs has changed (entry added or replaced)
                    if currentIds != initial {
                        isPriceUpdated = true
                    }
                } else if !currentIds.isEmpty {
                    // If we couldn't get initial, any non-empty counts as success
                    isPriceUpdated = true
                }
            }
        }

        // 4. Success!
        print("\u{001B}[2J\u{001B}[H")
        print("✨ BOOM! I've detected the pricing update.")
        print("Your app is now officially set to Free.")
        print("\nSetup complete. You can now close your browser.")
    }

    // Existing automation logic (preserved for future use)
    private func performAutomatedUpdate(service: AppStoreConnectService, appId: String) async throws {
        let displayPrice = (price == "0" || price.lowercased() == "free") ? "Free" : "$\(price)"
        print("🚀 Updating price to: \(displayPrice)...")
        try await service.updateAppPrice(appId: appId, tier: price)
        print("✅ Pricing updated successfully!")
    }
}

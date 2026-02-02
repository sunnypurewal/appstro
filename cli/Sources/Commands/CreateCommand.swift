import ArgumentParser
import Foundation

struct Create: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new app in App Store Connect."
    )

    @Argument(help: "The name of the app to create.")
    var name: String

    func run() async throws {
        // 1. Get credentials
        guard let issuerId = ProcessInfo.processInfo.environment["APPSTORE_ISSUER_ID"],
              let keyId = ProcessInfo.processInfo.environment["APPSTORE_KEY_ID"],
              let privateKey = ProcessInfo.processInfo.environment["APPSTORE_PRIVATE_KEY"] else {
            print("❌ Error: Missing App Store Connect credentials.")
            print("👉 Run 'appstro login' to set up your credentials.")
            return
        }

        let service = AppStoreConnectService(issuerId: issuerId, keyId: keyId, privateKey: privateKey)
        let prefService = PreferenceService()
        let prefs = prefService.loadPreferences()

        // 2. Deduction & Prep
        let deducedPrefix = try? await service.deduceBundleIdPrefix(preferredPrefix: prefs.lastUsedPrefix)
        let prefix = deducedPrefix ?? "com.example"
        var finalBundleId = "\(prefix).\(name.replacingOccurrences(of: " ", with: ""))"
        
        let locale = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
        let sku = "\(name.uppercased().replacingOccurrences(of: " ", with: "_"))_\(Int(Date().timeIntervalSince1970))"

        // 3. Initial Confirmation
        print("\n🚀 Preparing to create '\(name)'...")
        print("📦 Suggested Bundle ID: \(finalBundleId)")
        
        print("\nPress Enter to use this Bundle ID, or enter a custom one/prefix:")
        if let input = readLine(), !input.isEmpty {
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains(".") {
                finalBundleId = trimmed
                let parts = trimmed.split(separator: ".")
                if parts.count > 1 {
                    prefService.savePrefix(parts.dropLast().joined(separator: "."))
                }
            } else if trimmed.lowercased() != "y" {
                finalBundleId = "\(trimmed).\(name.replacingOccurrences(of: " ", with: ""))"
                prefService.savePrefix(trimmed)
            }
        }

        // 4. Pre-register Bundle ID
        print("\n⚙️  Configuring identifiers...")
        do {
            _ = try await service.registerBundleId(name: name, identifier: finalBundleId)
        } catch {
            print("❌ Failed to register Bundle ID: \(error)")
            return
        }

        // 5. The Transition UI
        print("\u{001B}[2J\u{001B}[H") // Clear screen
        print("✨ I've handled the technical setup for you.")
        print("I've registered the Bundle ID and generated a unique SKU.")
        print("\nTo finish setting up the app record, we'll head over to your browser.")
        print("💡 Keep this terminal window visible as you complete the setup.")
        
        print("\nReady to open App Store Connect? [Press Enter]")
        _ = readLine()

        // 6. Open Browser
        let urlString = "https://appstoreconnect.apple.com/apps"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [urlString]
        try? process.run()

        // 7. Magic Polling Loop & Cheat Sheet
        print("\u{001B}[2J\u{001B}[H") // Clear screen again
        print("🚀 Assistant Mode Active")
        print("-----------------------------------------------------------")
        print("1. If prompted, please log in to App Store Connect.")
        print("2. Ensure you are on the correct Team (matched to your API Key).")
        print("3. Click the Blue [+] button beside 'Apps' and select 'New App'.")
        print("4. Fill out the form using the details below and click 'Create'.")
        
        print("\n💡 Tip: Once you hit 'Create' in the browser, I'll take care of")
        print("   everything else for you.")
        
        print("\n📋 YOUR CHEAT SHEET:")
        print("-----------------------------------------------------------")
        print("PLATFORMS:        [X] iOS")
        print("NAME:             \(name)")
        print("PRIMARY LANGUAGE: \(Locale.current.localizedString(forIdentifier: locale) ?? locale)")
        print("BUNDLE ID:        Select \"\(name) (\(finalBundleId))\"")
        print("SKU:              \(sku)")
        print("USER ACCESS:      [X] Full Access")
        print("-----------------------------------------------------------")
        print("\n(I'll be right here...)")

        var detectedApp: AppData? = nil
        while detectedApp == nil {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            if let apps = try? await service.listApps() {
                detectedApp = apps.first { app in
                    app.attributes.bundleId == finalBundleId || 
                    app.attributes.name.localizedCaseInsensitiveCompare(name) == .orderedSame
                }
            }
        }

        // 8. Success!
        print("\u{001B}[2J\u{001B}[H")
        print("✨ BOOM! I see it. '\(name)' is officially created.")
        print("\nSetup complete. You can now close your browser.")
        if let app = detectedApp {
            print("🔗 View Dashboard: https://appstoreconnect.apple.com/apps/\(app.id)")
        }
    }
}
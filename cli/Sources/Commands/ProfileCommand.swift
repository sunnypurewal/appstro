import ArgumentParser
import Foundation

struct Profile: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "profile",
        abstract: "Manage provisioning profiles.",
        subcommands: [CreateProfile.self]
    )
}

struct CreateProfile: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new iOS App Store provisioning profile for the current app."
    )

    func run() async throws {
        // 1. Get credentials
        guard let issuerId = ProcessInfo.processInfo.environment["APPSTORE_ISSUER_ID"],
              let keyId = ProcessInfo.processInfo.environment["APPSTORE_KEY_ID"],
              let privateKey = ProcessInfo.processInfo.environment["APPSTORE_PRIVATE_KEY"] else {
            print("❌ Error: Missing App Store Connect credentials.")
            return
        }

        let service = try AppStoreConnectService(issuerId: issuerId, keyId: keyId, privateKey: privateKey)
        let projectService = ProjectService.shared

        // 2. Locate project root and config
        guard let projectRoot = projectService.findProjectRoot() else {
            print("❌ Error: Could not find project root (appstro.json).")
            return
        }

        let config = try projectService.loadConfig(at: projectRoot)
        let appName = config.name
        
        // 3. Deduce Bundle ID from Xcode project (or config if we add it there later)
        // For now, we'll use the convention from InitCommand: com.appstro.\(name)
        // Ideally we should read it from the .xcodeproj, but let's stick to the convention for simplicity
        // or try to find it via API if possible.
        print("🔍 Finding Bundle ID for \(appName)...")
        let apps = try await service.listApps()
        guard let appInfo = apps.first(where: { $0.name.localizedCaseInsensitiveCompare(appName) == .orderedSame }) else {
            print("❌ Error: App '\(appName)' not found in your App Store Connect account.")
            return
        }
        let bundleId = appInfo.bundleId
        print("📦 Found Bundle ID: \(bundleId)")

        // 4. Get Distribution Certificate
        print("🔍 Searching for Distribution Certificate...")
        let certId = try await service.findDistributionCertificateId()
        
        // 5. Get Bundle ID Record ID
        let bundleIdRecordId = try await service.findBundleIdRecordId(identifier: bundleId)

        // 6. Create Profile
        let profileName = "\(appName) App Store Distribution"
        print("🚀 Creating provisioning profile: \(profileName)...")
        
        let profileData = try await service.createProvisioningProfile(
            name: profileName,
            bundleIdRecordId: bundleIdRecordId,
            certificateId: certId
        )

        // 7. Save Profile
        let profileFileName = "\(appName).mobileprovision"
        let profileURL = projectRoot.appendingPathComponent(profileFileName)
        try profileData.write(to: profileURL)

        print("✅ Success! Provisioning profile created and saved to:")
        print("👉 \(profileURL.path)")
    }
}

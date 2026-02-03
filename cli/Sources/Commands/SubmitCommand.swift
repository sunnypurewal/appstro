import ArgumentParser
import Foundation

struct Submit: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "submit",
        abstract: "Submit the prepared app version for review."
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

        // 2. Load context from appstro.json
        guard let projectRoot = projectService.findProjectRoot(),
              let config = try? projectService.loadConfig(at: projectRoot) else {
            print("❌ Error: Could not find appstro.json. Please run this command from within an Appstro project.")
            return
        }

        // 3. Find the app on App Store Connect
        print("🔍 Fetching app details for '\(config.name)'...")
        let query = AppQuery(type: .name(config.name))
        guard let appDetails = try await service.fetchAppDetails(query: query) else {
            print("❌ Error: Could not find app with name '\(config.name)' on App Store Connect.")
            return
        }
        
        // We need the internal App ID. fetchAppDetails returns AppDetails which doesn't have the internal ID (only App Store ID in URL).
        // Let's find the app in the list to get its internal ID.
        let apps = try await service.listApps()
        guard let app = apps.first(where: { $0.bundleId == appDetails.bundleId }) else {
            print("❌ Error: Could not resolve internal ID for app '\(config.name)'.")
            return
        }

        // 4. Find latest draft version for this specific app
        print("🔍 Fetching draft version for \(app.name)...")
        guard let draft = try await service.findDraftVersion(for: app.id) else {
            print("❌ Error: No app version found for \(app.name).")
            return
        }

        switch draft.state {
        case .prepareForSubmission:
            print("📦 Target version: \(draft.version)")
            // Proceed to submit
        case .waitingForReview, .inReview:
            print("✅ \(app.name) version \(draft.version) is already \(draft.state == .waitingForReview ? "Waiting for Review" : "In Review").")
            return
        case .pendingAppleRelease, .pendingDeveloperRelease, .readyForSale:
            print("✅ \(app.name) version \(draft.version) is already approved or live (\(draft.state.rawValue)).")
            return
        case .rejected, .metadataRejected, .developerRejected:
            print("⚠️ \(app.name) version \(draft.version) was rejected (\(draft.state.rawValue)). Please address the issues in App Store Connect.")
            return
        default:
            print("ℹ️ \(app.name) version \(draft.version) is in state: \(draft.state.rawValue).")
            if draft.state != .prepareForSubmission {
                print("👉 Please ensure your app is in 'Prepare for Submission' state to submit via CLI.")
                return
            }
        }

        // 5. Submit for review
        print("🚀 Submitting \(app.name) version \(draft.version) for review...")
        do {
            try await service.submitForReview(appId: app.id, versionId: draft.id)
            print("✅ Version \(draft.version) submitted for review successfully!")
        } catch {
            print("❌ Failed to submit for review: \(error.localizedDescription)")
            throw error
        }
    }
}

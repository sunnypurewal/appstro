import AppstroCore
import AppstroASC
import ArgumentParser
import Foundation

struct CreateSubmission: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "create",
		abstract: "Create a new App Store version."
	)

	@Argument(help: "The version string for the new version (e.g., 1.0.1).")
	var version: String

	@Option(name: .long, help: "The platform for the new version (ios or macos).")
	var platform: String

	func run() async throws {
		// 1. Find project root and config
		guard let root = Environment.live.project.findProjectRoot() else {
			UI.error("Not in an Appstro project. Run 'appstro init' first.")
			return
		}
		
		let config = try Environment.live.project.loadConfig(at: root)
		
		// 2. Setup ASC Service
		let service: any AppStoreConnectService
		do {
			service = try Environment.live.asc(Environment.live.bezel)
		} catch {
			UI.error("\(error.localizedDescription)")
			return
		}

		let query = Environment.live.queryInterpreter.interpret(config.name)
		
		// 3. Fetch App
		let app: AppDetails = try await UI.step("Fetching app details", emoji: "🔍") {
			guard let app = try await service.apps.fetchAppDetails(query: query) else {
				throw NSError(domain: "Appstro", code: 404, userInfo: [NSLocalizedDescriptionKey: "App not found in App Store Connect."])
			}
			return app
		}

		// 4. Check for existing draft
		let existingDraft = try await service.versions.findDraftVersion(for: app.id)
		if let draft = existingDraft {
			UI.info("A pending version already exists: \(draft.version) (\(draft.state.rawValue))", emoji: "⚠️")
			return
		}

		// 5. Create new version
		try await UI.step("Creating version \(version)", emoji: "🚀") {
			_ = try await service.versions.createVersion(appId: app.id, versionString: version, platform: platform)
			_ = try await Environment.live.project.ensureReleaseDirectory(at: root, version: version)
		}

		UI.success("Version \(version) created successfully! 🎉")
	}
}

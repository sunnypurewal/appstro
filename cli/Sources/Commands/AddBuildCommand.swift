import AppstroCore
import AppstroASC
import ArgumentParser
import Foundation

struct AddBuild: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "add-build",
		abstract: "Attach the most recent successful uploaded build to the pending release version."
	)

	func run() async throws {
		// 1. Get service
		let service: any AppStoreConnectService
		do {
			service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
		} catch {
			UI.error("\(error.localizedDescription)")
			return
		}

		// 2. Load context from appstro.json
		guard let projectRoot = Environment.live.project.findProjectRoot(),
			  let config = try? Environment.live.project.loadConfig(at: projectRoot) else {
			UI.error("Could not find appstro.json. Please run this command from within an Appstro project.")
			return
		}

		// 3. Find the app on App Store Connect
		let app: AppDetails
		do {
			app = try await UI.step("Fetching app details for '\(config.name)'", emoji: "🔍") {
				let query = Environment.live.queryInterpreter.interpret(config.name)
				guard let app = try await service.apps.fetchAppDetails(query: query) else {
					throw NSError(domain: "AddBuildError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find app with name '\(config.name)' on App Store Connect."])
				}
				return app
			}
		} catch {
			UI.error("\(error.localizedDescription)")
			return
		}

		// 4. Find latest draft version
		let draft: DraftVersion
		do {
			draft = try await UI.step("Fetching draft version for \(app.name)", emoji: "🔍") {
				guard let draft = try await service.versions.findDraftVersion(for: app.id) else {
					throw NSError(domain: "AddBuildError", code: 404, userInfo: [NSLocalizedDescriptionKey: "No app version found for \(app.name)."])
				}
				return draft
			}
		} catch {
			UI.error("\(error.localizedDescription)")
			return
		}

		UI.info("Target version: \(draft.version) (State: \(draft.state.rawValue))", emoji: "📦")

		// 5. Fetch builds
		let builds: [BuildInfo]
		do {
			builds = try await UI.step("Fetching available builds", emoji: "🔍") {
				return try await service.versions.fetchBuilds(appId: app.id, version: nil)
			}
		} catch {
			UI.error("Failed to fetch builds: \(error.localizedDescription)")
			return
		}

		// 6. Find the most recent VALID build
		guard let latestValidBuild = builds.first(where: { $0.processingState == .valid }) else {
			UI.error("No valid builds found for \(app.name). Please ensure your build has finished processing on App Store Connect.")
			if let processingBuild = builds.first(where: { $0.processingState == .processing }) {
				UI.info("A build (\(processingBuild.version)) is currently processing. Please try again in a few minutes.", emoji: "⏳")
			}
			return
		}

		UI.info("Found latest valid build: \(latestValidBuild.version) (\(latestValidBuild.id))", emoji: "✅")

		// 7. Attach build to version
		do {
			try await UI.step("Attaching build to version \(draft.version)", emoji: "🔗") {
				try await service.versions.attachBuildToVersion(versionId: draft.id, buildId: latestValidBuild.id)
			}
			UI.success("Build attached to submission successfully!")
		} catch {
			UI.error("Failed to attach build: \(error.localizedDescription)")
			return
		}
	}
}

import AppstroCore
import AppstroASC
import ArgumentParser
import Foundation

struct AppClipCommand: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "app-clip",
		abstract: "Manage App Clip experiences.",
		subcommands: [DeleteAppClip.self]
	)
}

struct DeleteAppClip: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "delete",
		abstract: "Delete an App Clip experience."
	)

	@Argument(help: "The ID of the App Clip experience to delete. If not provided, it will be fetched automatically.")
	var id: String?

	@Flag(name: .shortAndLong, help: "Whether this is an advanced experience (defaults to false).")
	var advanced: Bool = false

	func run() async throws {
		// 1. Get service
		let service: any AppStoreConnectService
		do {
			service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
		} catch {
			UI.error("\(error.localizedDescription)")
			return
		}

		// 2. Determine target IDs
		var targetIds: [String] = []

		if let providedId = id {
			targetIds = [providedId]
		} else {
			// Automatic fetch
			guard let projectRoot = Environment.live.project.findProjectRoot(),
				  let config = try? Environment.live.project.loadConfig(at: projectRoot) else {
				UI.error("Could not find appstro.json. Please run this command from within an Appstro project or provide an ID.")
				return
			}

			let app: AppDetails = try await UI.step("Fetching app details for '\(config.name)'", emoji: "🔍") {
				let query = Environment.live.queryInterpreter.interpret(config.name)
				guard let app = try await service.apps.fetchAppDetails(query: query) else {
					throw NSError(domain: "AppClipError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find app on App Store Connect."])
				}
				return app
			}

			if advanced {
				targetIds = try await UI.step("Fetching advanced experiences", emoji: "🔍") {
					try await service.appClips.fetchAdvancedExperienceIds(appId: app.id)
				}
			} else {
				let draft = try await UI.step("Fetching draft version", emoji: "🔍") {
					guard let draft = try await service.versions.findDraftVersion(for: app.id) else {
						throw NSError(domain: "AppClipError", code: 404, userInfo: [NSLocalizedDescriptionKey: "No draft version found to fetch default experience from."])
					}
					return draft
				}

				if let defaultId = try await service.appClips.fetchDefaultExperienceId(versionId: draft.id) {
					targetIds = [defaultId]
				}
			}
		}

		// 3. Delete/Deactivate
		if targetIds.isEmpty {
			UI.info("No App Clip experiences found to delete.", emoji: "ℹ️")
			return
		}

		for targetId in targetIds {
			try await UI.step("Deleting experience \(targetId)", emoji: "🗑️") {
				if advanced {
					try await service.appClips.deactivateAdvancedExperience(id: targetId)
				} else {
					try await service.appClips.deleteDefaultExperience(id: targetId)
				}
			}
		}

		UI.success("✅ App Clip experience(s) deleted.")
	}
}

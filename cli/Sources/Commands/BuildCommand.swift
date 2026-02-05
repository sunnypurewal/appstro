import AppstroCore
import AppstroASC
import ArgumentParser
import Foundation

struct Build: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "build",
		abstract: "Build the RELEASE configuration of the app for App Store submission."
	)

	func run() async throws {
		// 1. Find project root and config
		guard let root = Environment.live.project.findProjectRoot() else {
			UI.error("Not in an Appstro project. Run 'appstro init' first.")
			return
		}
		
		var config = try Environment.live.project.loadConfig(at: root)

		// Auto-fetch Team ID if missing
		if config.teamID == nil {
			let appPath = config.appPath ?? "."
			let projectURL = root.appendingPathComponent(appPath)
			if let teamID = Environment.live.project.getTeamID(at: projectURL) {
				config = AppstroConfig(
					name: config.name,
					description: config.description,
					keywords: config.keywords,
					bundleIdentifier: config.bundleIdentifier,
					appPath: config.appPath,
					teamID: teamID
				)
				try? Environment.live.project.saveConfig(config, at: root)
				UI.info("Auto-detected Team ID: \(teamID)", emoji: "🆔")
			}
		}
		
		// 2. Get credentials and service
		let service: any AppStoreConnectService
		do {
			service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
		} catch {
			UI.error("\(error.localizedDescription)")
			return
		}
		
		// 3. Find App
		let query = Environment.live.queryInterpreter.interpret(config.name)
		let app: AppDetails
		do {
			app = try await UI.step("Finding app '\(config.name)' on App Store Connect", emoji: "🔍") {
				guard let app = try await service.apps.fetchAppDetails(query: query) else {
					throw NSError(domain: "BuildError", code: 404, userInfo: [NSLocalizedDescriptionKey: "App '\(config.name)' not found."])
				}
				return app
			}
		} catch {
			return
		}

		let nextBuildNumber: String
		do {
			nextBuildNumber = try await UI.step("Determining next build number", emoji: "🔢") {
				let builds = try await service.versions.fetchBuilds(appId: app.id, version: nil)
				let maxBuild = builds.compactMap { Int($0.version) }.max() ?? 0
				return String(maxBuild + 1)
			}
		} catch {
			return
		}

		let versionNumber: String
		do {
			versionNumber = try await UI.step("Determining app version", emoji: "🏷️") {
				guard let draft = try await service.versions.findDraftVersion(for: app.id) else {
					throw NSError(domain: "BuildError", code: 404, userInfo: [NSLocalizedDescriptionKey: "No draft version found for '\(config.name)' on App Store Connect."])
				}
				return draft.version
			}
		} catch {
			return
		}

		do {
			let ipaURL = try await UI.step("Building \(config.name) (Version \(versionNumber), Build \(nextBuildNumber))", emoji: "📦") {
				return try await Environment.live.project.build(at: root, config: config, version: versionNumber, buildNumber: nextBuildNumber)
			}
			UI.success("Build complete: \(ipaURL.path)")
			UI.info("You can now run 'appstro upload \(ipaURL.path)' to submit it.")
		} catch {
			UI.error("Build failed: \(error.localizedDescription)")
			return
		}
	}
}

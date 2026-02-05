import AppstroCore
import AppstroASC
import ArgumentParser
import Foundation

struct Cancel: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "cancel",
		abstract: "Cancel an active review submission."
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
					throw NSError(domain: "CancelError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find app with name '\(config.name)' on App Store Connect."])
				}
				return app
			}
		} catch {
			return
		}

		// 4. Cancel submission
		do {
			try await UI.step("Canceling active review submissions for \(app.name)", emoji: "🛑") {
				try await service.reviews.cancelReviewSubmission(appId: app.id)
			}
			UI.success("\(app.name) submissions have been canceled and returned to draft state.")
		} catch {
			UI.error("Failed to cancel submission: \(error.localizedDescription)")
			return
		}
	}
}

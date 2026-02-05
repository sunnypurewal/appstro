import AppstroCore
import AppstroASC
import ArgumentParser
import Foundation

struct Submit: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "submit",
		abstract: "Submit the prepared app version for review."
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
					throw NSError(domain: "SubmitError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find app with name '\(config.name)' on App Store Connect."])
				}
				return app
			}
		} catch {
			return
		}
		
		// 4. Find latest draft version
		let draft: DraftVersion
		do {
			draft = try await UI.step("Fetching draft version for \(app.name)", emoji: "🔍") {
				guard let draft = try await service.versions.findDraftVersion(for: app.id) else {
					throw NSError(domain: "SubmitError", code: 404, userInfo: [NSLocalizedDescriptionKey: "No app version found for \(app.name)."])
				}
				return draft
			}
		} catch {
			return
		}

		switch draft.state {
		case .prepareForSubmission, .rejected, .metadataRejected, .developerRejected:
			UI.info("Target version: \(draft.version) (\(draft.state.rawValue))", emoji: "📦")
			// Proceed to submit
		case .readyForSale:
			UI.success("\(app.name) version \(draft.version) is already live.")
			return
		case .waitingForReview, .inReview:
			UI.info("\(app.name) version \(draft.version) is already \(draft.state == .waitingForReview ? "waiting for review" : "in review").")
			return
		default:
			UI.info("\(app.name) version \(draft.version) is in state: \(draft.state.rawValue).")
			UI.info("Please ensure your app is in a submittable state (e.g., Prepare for Submission or Rejected) to submit via CLI.", emoji: "👉")
			return
		}

		// 5. Submit for review
		do {
			try await UI.step("Submitting \(app.name) version \(draft.version) for review", emoji: "🚀") {
				try await service.reviews.submitForReview(appId: app.id, versionId: draft.id)
			}
			UI.success("Version \(draft.version) submitted for review successfully!")
		} catch {
			// Error is already printed by UI.step
			throw error
		}
	}
}

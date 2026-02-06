import AppstroCore
import AppstroASC
import ArgumentParser
import Foundation

struct Attach: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "attach",
		abstract: "Attach a file for App Store review."
	)

	@Argument(help: "The path to the file to attach.")
	var filePath: String

	func run() async throws {
		// 1. Get service
		let service: any AppStoreConnectService
		do {
			service = try Environment.live.asc(Environment.live.bezel)
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

		// 3. Validate file exists
		let fileURL = URL(fileURLWithPath: filePath)
		guard FileManager.default.fileExists(atPath: fileURL.path) else {
			UI.error("File not found at \(filePath)")
			return
		}

		// 4. Find the app on App Store Connect
		let app: AppDetails
		do {
			app = try await UI.step("Fetching app details for '\(config.name)'", emoji: "🔍") {
				let query = Environment.live.queryInterpreter.interpret(config.name)
				guard let app = try await service.apps.fetchAppDetails(query: query) else {
					throw NSError(domain: "AttachError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find app with name '\(config.name)' on App Store Connect."])
				}
				return app
			}
		} catch {
			return
		}

		// 5. Find latest draft version
		let draft: DraftVersion
		do {
			draft = try await UI.step("Fetching draft version for \(app.name)", emoji: "🔍") {
				guard let draft = try await service.versions.findDraftVersion(for: app.id) else {
					throw NSError(domain: "AttachError", code: 404, userInfo: [NSLocalizedDescriptionKey: "No app version found for \(app.name)."])
				}
				return draft
			}
		} catch {
			return
		}

		UI.info("Target version: \(draft.version) (State: \(draft.state.rawValue))", emoji: "📦")

		// 6. Upload attachment
		do {
			try await UI.step("Uploading attachment '\(fileURL.lastPathComponent)'", emoji: "🚀") {
				try await service.reviews.uploadReviewAttachment(versionId: draft.id, fileURL: fileURL)
			}
			UI.success("File attached to submission successfully!")
		} catch {
			UI.error("Failed to upload attachment: \(error.localizedDescription)")
			return
		}
	}
}

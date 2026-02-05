import AppstroCore
import AppstroASC
import ArgumentParser
import Foundation

struct Privacy: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "privacy",
		abstract: "Update the app's privacy policy and data collection info."
	)

	@Option(name: .long, help: "The URL of the privacy policy.")
	var url: String?

	func run() async throws {
		// 1. Get service
		let service: any AppStoreConnectService
		do {
			service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
		} catch {
			UI.error("\(error.localizedDescription)")
			return
		}

		// 2. Find project root and config
		guard let root = Environment.live.project.findProjectRoot() else {
			UI.error("Not in an Appstro project. Run 'appstro init' first.")
			return
		}
		
		let config = try Environment.live.project.loadConfig(at: root);
		
		// 3. Find App
		let app: AppDetails
		do {
			app = try await UI.step("Fetching app details", emoji: "🔍") {
				let query = Environment.live.queryInterpreter.interpret(config.name)
				guard let app = try await service.apps.fetchAppDetails(query: query) else {
					throw NSError(domain: "PrivacyError", code: 404, userInfo: [NSLocalizedDescriptionKey: "App '\(config.name)' not found on App Store Connect."])
				}
				return app
			}
		} catch {
			return
		}

		var targetUrl = url
		if targetUrl == nil {
			print("🔗 Enter the Privacy Policy URL:")
			targetUrl = readLine()
		}
		
		guard let urlString = targetUrl, let finalUrl = URL(string: urlString) else {
			UI.error("Invalid URL.")
			return
		}

		do {
			try await UI.step("Updating Privacy Policy URL to: \(finalUrl.absoluteString)", emoji: "🚀") {
				try await service.metadata.updatePrivacyPolicy(appId: app.id, url: finalUrl)
			}
			UI.success("Privacy Policy updated successfully!")
		} catch {
			return
		}
	}
}

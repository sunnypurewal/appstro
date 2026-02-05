import AppstroCore
import AppstroASC
import ArgumentParser
import Foundation

struct App: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app",
        abstract: "Fetch details of an app from App Store Connect."
    )

    @Argument(help: "The name of the app or its bundle identifier.")
    var parameter: String

	func run() async throws {
		// 1. Interpret the parameter
		let query = Environment.live.queryInterpreter.interpret(parameter)
		
		// 2. Get service
		let service: any AppStoreConnectService
		do {
			service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
		} catch {
			UI.error("\(error.localizedDescription)")
			UI.info("Run 'appstro login' to find your credentials and see setup instructions.", emoji: "👉")
			return
		}
		
		let details: AppDetails?
		do {
			details = try await UI.step("Searching for app '\(parameter)'", emoji: "🔍") {
				return try await service.apps.fetchAppDetails(query: query)
			}
		} catch {
			return
		}
		
		if let details = details {
			print("")
			UI.info("App Details:", emoji: "📱")
			print("-------------------")
			print("Name:           \(details.name)")
			print("Bundle ID:      \(details.bundleId)")
			print("App Store URL:  \(details.appStoreUrl)")
			
			if let version = details.publishedVersion {
				print("Status:         Published")
				print("Active Version: \(version)")
			} else {
				print("Status:         No published version exists")
			}
		} else {
			UI.error("No app found matching: \(parameter)")
		}
	}
}

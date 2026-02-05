import AppstroCore
import AppstroASC
import ArgumentParser
import Foundation

struct ContentRights: AsyncParsableCommand {

	static let configuration = CommandConfiguration(

		commandName: "content-rights",

		abstract: "Declare if the app uses third-party content."

	)



	@Flag(name: .long, help: "Explicitly set that the app uses third-party content.")

	var usesThirdParty: Bool = false



	@Flag(name: .shortAndLong, help: "Skip analysis and prompts.")

	var yes: Bool = false



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

		var contextName: String?

		var contextPitch: String?

		

		if let root = Environment.live.project.findProjectRoot(),

		   let config = try? Environment.live.project.loadConfig(at: root) {

			contextName = config.name

			contextPitch = config.description

			UI.info("Loaded context from appstro.json", emoji: "📖")

		}



		let draft: (app: AppInfo, version: String, id: String)

		do {

			draft = try await UI.step("Checking draft version", emoji: "🔍") {

				let apps = try await service.apps.listApps()

				for app in apps {

					if let draft = try await service.versions.findDraftVersion(for: app.id), draft.state == .prepareForSubmission {

						return (app: app, version: draft.version, id: draft.id)

					}

				}

				throw NSError(domain: "ContentRightsError", code: 404, userInfo: [NSLocalizedDescriptionKey: "No app version in 'Prepare for Submission' state found."])

			}

		} catch {

			return

		}



		var finalValue = usesThirdParty



		if !yes {

			let analysis = try? await UI.step("Analyzing content rights", emoji: "🔍") {

				return try await Environment.live.ai.analyzeContentRights(appName: contextName ?? draft.app.name, description: contextPitch ?? "No description available.")

			}

			

			if let analysis = analysis {

				if analysis.usesThirdPartyContent {

					UI.info("Analysis suggests this app MIGHT use third-party content.", emoji: "⚠️")

					print("Reasoning: \(analysis.reasoning)")

					print("Does this app use third-party content? [Y/n]")

					let answer = readLine()?.lowercased()

					finalValue = (answer == "" || answer == "y")

				} else {

					UI.success("Analysis suggests no third-party content rights are needed.")

					print("Does this app use third-party content? [y/N]")

					let answer = readLine()?.lowercased()

					finalValue = (answer == "y")

				}

			} else {

				UI.info("No analysis available.", emoji: "ℹ️")

				var answer: String?

				while answer != "y" && answer != "n" {

					print("Does this app use third-party content? [y/n]")

					answer = readLine()?.lowercased()

				}

				finalValue = (answer == "y")

			}

		}



		do {

			try await UI.step("Updating Content Rights", emoji: "🚀") {

				try await service.apps.updateContentRights(appId: draft.app.id, usesThirdPartyContent: finalValue)

			}

			UI.success("Content Rights updated successfully!")

		} catch {

			return

		}

	}

}

import AppstroCore
import AppstroASC
import ArgumentParser
import Foundation

struct AgeRatings: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "age-ratings",
        abstract: "Update the app's age rating declaration."
    )

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
		var contextName: String?
		var contextPitch: String?
		var contextAppPath: String?
		
		if let root = Environment.live.project.findProjectRoot(),
		   let config = try? Environment.live.project.loadConfig(at: root) {
			contextName = config.name
			contextPitch = config.description
			contextAppPath = config.appPath
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
				throw NSError(domain: "AgeRatingError", code: 404, userInfo: [NSLocalizedDescriptionKey: "No app version in 'Prepare for Submission' state found."])
			}
		} catch {
			return
		}

		let codeContext: String
		do {
			codeContext = try await UI.step("Reading project context", emoji: "📄") {
				let baseDir = Environment.live.project.findProjectRoot() ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
				let rootDir = contextAppPath.map { baseDir.appendingPathComponent($0) } ?? baseDir
				let sourcesDir = rootDir.appendingPathComponent("Sources")
				
				var context = ""
				let fileManager = FileManager.default
				if let files = try? fileManager.contentsOfDirectory(at: sourcesDir, includingPropertiesForKeys: nil) {
					for file in files where file.pathExtension == "swift" {
						if let content = try? String(contentsOf: file, encoding: .utf8) {
							context += "\n--- \(file.lastPathComponent) ---\n\(content)\n"
						}
					}
				}
				return context
			}
		} catch {
			return
		}

		var suggestions: SuggestedAgeRatings?
		let aiResult = try? await UI.step("Analyzing app for age ratings", emoji: "🔍") {
			return try await Environment.live.ai.suggestAgeRatings(appName: contextName ?? draft.app.name, description: contextPitch ?? "", codeContext: codeContext)
		}
		
		if let aiSuggestions = aiResult {
			suggestions = aiSuggestions
			UI.info("Suggested age ratings based on your app.", emoji: "📋")
			print("Reasoning: \(aiSuggestions.reasoning)")
		} else {
			UI.info("No analysis available. Using 'None' as default for all categories.")
		}

		let finalRatings = SuggestedAgeRatings(
			alcoholTobaccoOrDrugUseOrReference: suggestions?.alcoholTobaccoOrDrugUseOrReference ?? "NONE",
			gamblingAndContests: suggestions?.gamblingAndContests ?? false,
			gamblingSimulated: suggestions?.gamblingSimulated ?? "NONE",
			horrorOrFearThemes: suggestions?.horrorOrFearThemes ?? "NONE",
			matureOrSuggestiveThemes: suggestions?.matureOrSuggestiveThemes ?? "NONE",
			medicalOrTreatmentInformation: suggestions?.medicalOrTreatmentInformation ?? "NONE",
			profanityOrCrudeHumor: suggestions?.profanityOrCrudeHumor ?? "NONE",
			sexualContentOrNudity: suggestions?.sexualContentOrNudity ?? "NONE",
			sexualContentGraphicOrNudity: suggestions?.sexualContentGraphicOrNudity ?? "NONE",
			violenceCartoonOrFantasy: suggestions?.violenceCartoonOrFantasy ?? "NONE",
			violenceRealistic: suggestions?.violenceRealistic ?? "NONE",
			violenceRealisticProlongedGraphicOrSadistic: suggestions?.violenceRealisticProlongedGraphicOrSadistic ?? "NONE",
			gunsOrOtherWeapons: suggestions?.gunsOrOtherWeapons ?? "NONE",
			parentalControls: suggestions?.parentalControls ?? false,
			userGeneratedContent: suggestions?.userGeneratedContent ?? false,
			ageAssurance: suggestions?.ageAssurance ?? false,
			advertising: suggestions?.advertising ?? false,
			healthOrWellnessTopics: suggestions?.healthOrWellnessTopics ?? false,
			messagingAndChat: suggestions?.messagingAndChat ?? "NONE",
			unrestrictedWebAccess: suggestions?.unrestrictedWebAccess ?? false,
			kids17Plus: suggestions?.kids17Plus ?? false,
			isLootBox: suggestions?.isLootBox ?? false,
			kidsAgeBand: suggestions?.kidsAgeBand,
			koreaAgeRatingOverride: suggestions?.koreaAgeRatingOverride ?? "NONE",
			reasoning: ""
		)
				
		print("\n--- PROPOSED AGE RATINGS ---")
		print("Violence (Cartoon): \(finalRatings.violenceCartoonOrFantasy)")
		print("Violence (Realistic): \(finalRatings.violenceRealistic)")
		print("Guns/Other Weapons: \(finalRatings.gunsOrOtherWeapons)")
		print("Profanity/Crude Humor: \(finalRatings.profanityOrCrudeHumor)")
		print("Mature/Suggestive: \(finalRatings.matureOrSuggestiveThemes)")
		print("Gambling (Simulated): \(finalRatings.gamblingSimulated)")
		print("Messaging & Chat: \(finalRatings.messagingAndChat)")
		print("User Generated Content: \(finalRatings.userGeneratedContent ? "YES" : "NO")")
		print("Advertising: \(finalRatings.advertising ? "YES" : "NO")")
		print("Health/Wellness Topics: \(finalRatings.healthOrWellnessTopics ? "YES" : "NO")")
		print("Parental Controls: \(finalRatings.parentalControls ? "YES" : "NO")")
		print("Age Assurance: \(finalRatings.ageAssurance ? "YES" : "NO")")
		print("Unrestricted Web: \(finalRatings.unrestrictedWebAccess ? "YES" : "NO")")
		print("Purchasable Loot Boxes: \(finalRatings.isLootBox ? "YES" : "NO")")
		if let band = finalRatings.kidsAgeBand {
			print("Kids Age Band: \(band)")
		}
		print("Korea Override: \(finalRatings.koreaAgeRatingOverride)")
		print("----------------------------\n")
		
		if suggestions != nil {
			let answer = UI.prompt("Do you want to apply these ratings?", defaultValue: "y").lowercased()
			if answer == "y" {
				do {
					try await UI.step("Updating Age Rating Declaration", emoji: "🚀") {
						try await service.ageRatings.updateAgeRatingDeclaration(versionId: draft.id, ratings: finalRatings)
					}
					UI.success("Age Ratings updated successfully!")
				} catch {
					return
				}
			} else {
				UI.info("Cancelled.", emoji: "❌")
			}
		} else {
			let answer = UI.prompt("Do you want to apply these ratings?", defaultValue: "n").lowercased()
			if answer == "y" {
				do {
					try await UI.step("Updating Age Rating Declaration", emoji: "🚀") {
						try await service.ageRatings.updateAgeRatingDeclaration(versionId: draft.id, ratings: finalRatings)
					}
					UI.success("Age Ratings updated successfully!")
				} catch {
					return
				}
			} else {
				UI.info("Cancelled.", emoji: "❌")
			}
		}
	}
}
        

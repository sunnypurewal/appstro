import ArgumentParser
import Foundation

struct AgeRatings: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "age-ratings",
        abstract: "Update the app's age rating declaration."
    )

    func run() async throws {
        guard let issuerId = ProcessInfo.processInfo.environment["APPSTORE_ISSUER_ID"],
              let keyId = ProcessInfo.processInfo.environment["APPSTORE_KEY_ID"],
              let privateKey = ProcessInfo.processInfo.environment["APPSTORE_PRIVATE_KEY"] else {
            print("❌ Error: Missing App Store Connect credentials.")
            return
        }

        let service = try AppStoreConnectService(issuerId: issuerId, keyId: keyId, privateKey: privateKey)
        let aiService = AIService()

        // Load context from appstro.json
        var contextName: String?
        var contextPitch: String?
        var contextAppPath: String?
        
        let fileManager = FileManager.default
        var currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        var configURL: URL?

        for _ in 0...3 {
            let checkURL = currentDir.appendingPathComponent("appstro.json")
            if fileManager.fileExists(atPath: checkURL.path) {
                configURL = checkURL
                if let data = try? Data(contentsOf: checkURL),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    contextName = json["name"]
                    contextPitch = json["description"]
                    contextAppPath = json["app_path"]
                    print("📖 Loaded context from appstro.json")
                }
                break
            }
            currentDir = currentDir.deletingLastPathComponent()
        }

        print("🔍 Checking draft version...")
        guard let draft = try await service.findLatestDraftVersion() else {
            print("❌ No app version in 'Prepare for Submission' state found.")
            return
        }

        var codeContext = ""
        if let configURL = configURL {
            let baseDir = configURL.deletingLastPathComponent()
            let rootDir = contextAppPath.map { baseDir.appendingPathComponent($0) } ?? baseDir
            let sourcesDir = rootDir.appendingPathComponent("Sources")
            
            if let files = try? fileManager.contentsOfDirectory(at: sourcesDir, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "swift" {
                    if let content = try? String(contentsOf: file, encoding: .utf8) {
                        codeContext += "\n--- \(file.lastPathComponent) ---\n\(content)\n"
                    }
                }
            }
        }

        var suggestions: SuggestedAgeRatings?
        if let aiSuggestions = try? await aiService.suggestAgeRatings(appName: contextName ?? draft.app.name, description: contextPitch ?? "", codeContext: codeContext) {
            suggestions = aiSuggestions
            print("🤖 AI has suggested age ratings based on your app.")
            print("Reasoning: \(aiSuggestions.reasoning)")
        } else {
            print("ℹ️ No AI analysis available. Using 'None' as default for all categories.")
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
                                    unrestrictedWebAccess: suggestions?.unrestrictedWebAccess ?? false,
                                    kids17Plus: suggestions?.kids17Plus ?? false,
                                    isLootBox: suggestions?.isLootBox ?? false,
                                    kidsAgeBand: suggestions?.kidsAgeBand,
                                    koreaAgeRatingOverride: suggestions?.koreaAgeRatingOverride ?? "NONE",
                                    reasoning: ""
                                )
                        
                                print("\n--- PROPOSED AGE RATINGS ---")
                                print("Violence (Cartoon):       \(finalRatings.violenceCartoonOrFantasy)")
                                print("Violence (Realistic):     \(finalRatings.violenceRealistic)")
                                print("Profanity/Crude Humor:    \(finalRatings.profanityOrCrudeHumor)")
                                print("Mature/Suggestive:        \(finalRatings.matureOrSuggestiveThemes)")
                                print("Gambling (Simulated):     \(finalRatings.gamblingSimulated)")
                                print("Unrestricted Web:         \(finalRatings.unrestrictedWebAccess ? "YES" : "NO")")
                                print("Purchasable Loot Boxes:   \(finalRatings.isLootBox ? "YES" : "NO")")
                                if let band = finalRatings.kidsAgeBand {
                                    print("Kids Age Band:            \(band)")
                                }
                                print("Korea Override:           \(finalRatings.koreaAgeRatingOverride)")
                                print("----------------------------\n")
                        
                            if suggestions != nil {
                    print("Do you want to apply these ratings? [Y/n]")
                    let answer = readLine()?.lowercased()
                    if answer == "" || answer == "y" {
                        print("🚀 Updating Age Rating Declaration...")
                        try await service.updateAgeRatingDeclaration(versionId: draft.id, ratings: finalRatings)
                        print("✅ Age Ratings updated successfully!")
                    } else {
                        print("❌ Cancelled.")
                    }
                } else {
                    print("Do you want to apply these ratings? [y/N]")
                    if let answer = readLine()?.lowercased(), answer == "y" {
                        print("🚀 Updating Age Rating Declaration...")
                        try await service.updateAgeRatingDeclaration(versionId: draft.id, ratings: finalRatings)
                        print("✅ Age Ratings updated successfully!")
                    } else {
                        print("❌ Cancelled.")
                    }
                }
            }
        }
        
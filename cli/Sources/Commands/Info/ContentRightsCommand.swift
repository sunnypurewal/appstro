import ArgumentParser
import Foundation

struct ContentRights: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "content-rights",
        abstract: "Declare if the app uses third-party content."
    )

    @Flag(name: .long, help: "Explicitly set that the app uses third-party content.")
    var usesThirdParty: Bool = false

    @Flag(name: .shortAndLong, help: "Skip AI analysis and prompts.")
    var yes: Bool = false

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
        
        let fileManager = FileManager.default
        var currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        for _ in 0...3 {
            let checkURL = currentDir.appendingPathComponent("appstro.json")
            if fileManager.fileExists(atPath: checkURL.path) {
                if let data = try? Data(contentsOf: checkURL),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    contextName = json["name"]
                    contextPitch = json["description"]
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

        var finalValue = usesThirdParty

        if !yes {
            if let analysis = try? await aiService.analyzeContentRights(appName: contextName ?? draft.app.name, description: contextPitch ?? "No description available.") {
                if analysis.usesThirdPartyContent {
                    print("⚠️ AI suggests this app MIGHT use third-party content.")
                    print("🤖 Reasoning: \(analysis.reasoning)")
                    print("Does this app use third-party content? [Y/n]")
                    let answer = readLine()?.lowercased()
                    finalValue = (answer == "" || answer == "y")
                } else {
                    print("✅ AI suggests no third-party content rights are needed.")
                    print("Does this app use third-party content? [y/N]")
                    let answer = readLine()?.lowercased()
                    finalValue = (answer == "y")
                }
            } else {
                print("ℹ️ No AI analysis available.")
                var answer: String?
                while answer != "y" && answer != "n" {
                    print("Does this app use third-party content? [y/n]")
                    answer = readLine()?.lowercased()
                }
                finalValue = (answer == "y")
            }
        }

        print("🚀 Updating Content Rights to: \(finalValue ? "Uses Third-Party Content" : "Does Not Use Third-Party Content")...")
        try await service.updateContentRights(appId: draft.app.id, usesThirdPartyContent: finalValue)
        print("✅ Content Rights updated successfully!")
    }
}
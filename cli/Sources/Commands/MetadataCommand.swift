import ArgumentParser
import Foundation

struct Metadata: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "metadata",
        abstract: "Generate and upload app metadata using AI."
    )

    @Option(name: .long, help: "A short pitch or description of the app to guide the AI.")
    var pitch: String?

    func run() async throws {
        // 1. Get credentials
        guard let issuerId = ProcessInfo.processInfo.environment["APPSTORE_ISSUER_ID"],
              let keyId = ProcessInfo.processInfo.environment["APPSTORE_KEY_ID"],
              let privateKey = ProcessInfo.processInfo.environment["APPSTORE_PRIVATE_KEY"] else {
            print("❌ Error: Missing App Store Connect credentials.")
            return
        }

        let service = try AppStoreConnectService(issuerId: issuerId, keyId: keyId, privateKey: privateKey)
        let aiService = AIService()

        // 2. Load context from appstro.json if it exists
        var contextName: String?
        var contextPitch: String?
        var contextAppPath: String?
        
        let fileManager = FileManager.default
        var currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        var configURL: URL?

        // Look for appstro.json in current or parent directories
        for _ in 0...3 {
            let checkURL = currentDir.appendingPathComponent("appstro.json")
            if fileManager.fileExists(atPath: checkURL.path) {
                configURL = checkURL
                break
            }
            currentDir = currentDir.deletingLastPathComponent()
        }

        if let configURL = configURL,
           let data = try? Data(contentsOf: configURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            contextName = json["name"]
            contextPitch = json["description"]
            contextAppPath = json["app_path"]
            print("📖 Loaded context from appstro.json")
        }

        print("🔍 Fetching draft version...")
        guard let draft = try await service.findLatestDraftVersion() else {
            print("❌ No app version in 'Prepare for Submission' state found.")
            return
        }

        print("📄 Reading project context...")
        // Use directory where appstro.json was found + app_path, or current dir
        let baseDir = configURL?.deletingLastPathComponent() ?? URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let rootDir = contextAppPath.map { baseDir.appendingPathComponent($0) } ?? baseDir
        let sourcesDir = rootDir.appendingPathComponent("Sources")
        
        var codeContext = ""
        if let files = try? fileManager.contentsOfDirectory(at: sourcesDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "swift" {
                if let content = try? String(contentsOf: file, encoding: .utf8) {
                    codeContext += "\n--- \(file.lastPathComponent) ---\n\(content)\n"
                }
            }
        }

        if codeContext.isEmpty {
            print("⚠️ No Swift files found in Sources directory. Metadata might be generic.")
        }

        print("🤖 Generating metadata with AI...")
        let metadata = try await aiService.generateMetadata(
            appName: contextName ?? draft.app.name,
            codeContext: codeContext,
            userPitch: pitch ?? contextPitch
        )

        print("\n--- PROPOSED METADATA ---")
        print("📝 Description: \(metadata.description.prefix(100))...")
        print("🔑 Keywords: \(metadata.keywords)")
        print("📣 Promotional Text: \(metadata.promotionalText)")
        print("🗒️ Review Notes: \(metadata.reviewNotes)")
        print("------------------------\n")

        print("Do you want to upload this metadata? [y/N]")
        if let answer = readLine()?.lowercased(), answer == "y" {
            var contactInfo = try await service.fetchContactInfo()
            
            if contactInfo.firstName == nil {
                print("👤 Enter App Review Contact First Name:")
                contactInfo.firstName = readLine()
            }
            if contactInfo.lastName == nil {
                print("👤 Enter App Review Contact Last Name:")
                contactInfo.lastName = readLine()
            }
            if contactInfo.email == nil {
                print("📧 Enter App Review Contact Email:")
                contactInfo.email = readLine()
            }
            if contactInfo.phone == nil {
                print("📱 Enter App Review Contact Phone (e.g., +1 555-555-5555):")
                contactInfo.phone = readLine()
            }

            let domain = contactInfo.email?.split(separator: "@").last.map(String.init) ?? "example.com"
            let urls = (
                support: "https://\(domain)/support",
                marketing: "https://\(domain)"
            )
            
            let teamName = (contactInfo.firstName ?? "") + " " + (contactInfo.lastName ?? "")
            let copyright = "© \(Calendar.current.component(.year, from: Date())) \(teamName.trimmingCharacters(in: .whitespaces))"

            print("🚀 Uploading metadata to App Store Connect...")
            try await service.updateMetadata(
                versionId: draft.id,
                metadata: metadata,
                urls: urls,
                copyright: copyright,
                contactInfo: contactInfo
            )
            print("✅ Metadata updated successfully!")
        } else {
            print("❌ Upload cancelled.")
        }
    }
}

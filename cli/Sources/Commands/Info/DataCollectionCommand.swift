import ArgumentParser
import Foundation

struct DataCollection: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "data-collection",
        abstract: "Guide through the app's privacy data collection questionnaire on App Store Connect, with AI assistance."
    )

    func run() async throws {
        // 1. Get credentials
        guard let issuerId = ProcessInfo.processInfo.environment["APPSTORE_ISSUER_ID"],
              let keyId = ProcessInfo.processInfo.environment["APPSTORE_KEY_ID"],
              let privateKey = ProcessInfo.processInfo.environment["APPSTORE_PRIVATE_KEY"] else {
            print("❌ Error: Missing App Store Connect credentials.")
            print("👉 Run 'appstro login' to set up your credentials.")
            return
        }

        // 2. Show initial output immediately
        print("✨ We're now going to guide you through the App Privacy section on App Store Connect.")
        print("This process requires manual input on the Apple website.")
        print("👉 Please follow the prompts in this terminal while navigating the webpage.")

        // 3. Preparation Task (Fetch draft and read files)
        let preparationTask = Task { () -> (appId: String, appName: String, codeContext: String)? in
            guard let service = try? AppStoreConnectService(issuerId: issuerId, keyId: keyId, privateKey: privateKey) else { return nil }
            guard let draft = try? await service.findLatestDraftVersion() else { return nil }

            let fileManager = FileManager.default
            var codeContext = ""
            var contextAppPath: String?
            var currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            var configURL: URL?

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
                contextAppPath = json["app_path"]
            }

            let baseDir = configURL?.deletingLastPathComponent() ?? URL(fileURLWithPath: fileManager.currentDirectoryPath)
            let rootDir = contextAppPath.map { baseDir.appendingPathComponent($0) } ?? baseDir
            
            if let enumerator = fileManager.enumerator(at: rootDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                while let fileURL = enumerator.nextObject() as? URL {
                    if fileURL.pathExtension == "swift" {
                        if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                            codeContext += "\n--- \(fileURL.lastPathComponent) ---\n\(content)\n"
                        }
                    }
                }
            }
            return (draft.app.id, draft.app.name, codeContext)
        }

        // 4. AI Analysis Task (Starts as soon as preparation is done)
        let aiAnalysisTask = Task { () -> DataCollectionAnalysis? in
            guard let prep = await preparationTask.value else { return nil }
            let aiService = AIService()
            return try? await aiService.analyzeDataCollection(appName: prep.appName, codeContext: prep.codeContext)
        }

        print("\nReady to open App Store Connect? [Press Enter]")
        _ = readLine()

        // 5. Ensure preparation is complete before proceeding
        guard let prep = await preparationTask.value else {
            print("❌ Error: Could not find an app version in 'Prepare for Submission' state.")
            print("👉 Please ensure you have an app version ready for submission in App Store Connect.")
            return
        }

        let appId = prep.appId
        let appStoreConnectPrivacyURL = "https://appstoreconnect.apple.com/apps/\(appId)/distribution/privacy"

        print("🌐 Opening: \(appStoreConnectPrivacyURL)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [appStoreConnectPrivacyURL]
        try? process.run()
        
        // Wait for analysis result (it likely finished while user was opening browser)
        let aiAnalysis = await aiAnalysisTask.value

        print("\u{001B}[2J\u{001B}[H") // Clear screen
        print("🚀 Assistant Mode Active: App Privacy Questionnaire")
        print("-----------------------------------------------------------")
        print("1. Click 'Get Started' (or 'Edit' if you've started before) in the 'App Privacy' section.")
        print("2. Answer the first question:")
        print("   'Do you or your third-party partners collect data from this app?'")
        
        let recommendation = aiAnalysis?.collectsData ?? true
        if let analysis = aiAnalysis {
            print("   👉 Recommendation: Select '\(analysis.collectsData ? "Yes" : "No")'")
            print("   💡 Reasoning: \(analysis.reasoning)")
        } else {
            print("   Based on your knowledge, select 'Yes' or 'No'.")
        }
        
        let promptSuffix = recommendation ? "Y/n" : "y/N"
        print("\n   What did you answer in App Store Connect? (\(promptSuffix)): ", terminator: "")
        let collectDataAnswer = readLine()?.lowercased() ?? ""

        let selectedNo = (recommendation && (collectDataAnswer == "n" || collectDataAnswer == "no")) ||
                         (!recommendation && (collectDataAnswer == "n" || collectDataAnswer == "no" || collectDataAnswer.isEmpty))

        if selectedNo {
            print("\u{001B}[2J\u{001B}[H") // Clear screen
            print("✅ App Privacy Questionnaire Guide Complete!")
            print("Since no data is collected, there are no further questions to answer.")
            print("Please review your selection on App Store Connect and click 'Publish'.")
            return
        }

        print("\u{001B}[2J\u{001B}[H") // Clear screen
        print("🚀 Assistant Mode Active: App Privacy Questionnaire")
        print("-----------------------------------------------------------")
        print("3. On the 'Data Collection' screen, you'll see various data types.")
        print("   For each data type, you need to indicate if you collect it.")
        
        if let analysis = aiAnalysis {
            print("   👉 Identified Data Types:")
            let dt = analysis.dataTypes
            let types = [
                ("Location", dt.location),
                ("Contact Info", dt.contactInfo),
                ("Health and Fitness", dt.healthAndFitness),
                ("Financial Info", dt.financialInfo),
                ("User Content", dt.userContent),
                ("Browsing History", dt.browsingHistory),
                ("Search History", dt.searchHistory),
                ("Identifiers", dt.identifiers),
                ("Usage Data", dt.usageData),
                ("Diagnostics", dt.diagnostics),
                ("Other Data", dt.otherData)
            ]
            
            let identified = types.filter { $0.1 }.map { $0.0 }
            if identified.isEmpty {
                print("     - No specific data types were identified after analysis.")
            } else {
                for type in identified {
                    print("     ✅ \(type)")
                }
            }
            print("\n   Select these types on the webpage and click 'Next'.")
        } else {
            print("   Refer to your own understanding of the app to select the data types.")
            print("   Commonly collected data types include 'Usage Data', 'Diagnostics', and 'Identifiers'.")
            print("   Once you've made all selections, click 'Next'.")
        }
        
        print("\n   Press Enter when you are done.")
        _ = readLine()
        
        print("\u{001B}[2J\u{001B}[H") // Clear screen
        print("🚀 Assistant Mode Active: App Privacy Questionnaire")
        print("-----------------------------------------------------------")
        print("4. For each data type you selected as 'Yes', you will now be asked:")
        print("   'Is all of the data collected from this app linked to the user’s identity?'")
        print("   Answer 'Yes' or 'No' as appropriate for each type. Many analytics services do link data.")
        print("   Press Enter when you have made your selections and clicked 'Next'.")
        _ = readLine()

        print("\u{001B}[2J\u{001B}[H") // Clear screen
        print("🚀 Assistant Mode Active: App Privacy Questionnaire")
        print("-----------------------------------------------------------")
        print("5. Next, for each data type, you will be asked:")
        print("   'Does all of the data collected from this app track the user?'")
        print("   This refers to tracking across apps and websites owned by other companies.")
        print("   Answer 'Yes' or 'No' as appropriate. If you use third-party analytics that track, select 'Yes'.")
        print("   Press Enter when you have made your selections and clicked 'Next'.")
        _ = readLine()

        print("\u{001B}[2J\u{001B}[H") // Clear screen
        print("🚀 Assistant Mode Active: App Privacy Questionnaire")
        print("-----------------------------------------------------------")
        print("6. Finally, for each data type, you will be asked:")
        print("   'Do you use the data to perform the following purposes?'")
        print("   Select all purposes that apply (e.g., 'App Functionality', 'Analytics', 'Product Personalization').")
        print("   Press Enter when you have made your selections and clicked 'Next'.")
        _ = readLine()

        print("\u{001B}[2J\u{001B}[H") // Clear screen
        print("✅ App Privacy Questionnaire Guide Complete!")
        print("Please review your answers on the App Store Connect website and click 'Publish'.")
        print("You can now close your browser and this terminal session for App Privacy.")
    }
}

import AppstroCore
import AppstroASC
import ArgumentParser
import Foundation

struct DataCollection: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "data-collection",
        abstract: "Guide through the app's privacy data collection questionnaire on App Store Connect."
    )

    func run() async throws {
        // 1. Show initial output immediately
        UI.info("We're now going to guide you through the App Privacy section on App Store Connect.", emoji: "✨")
        UI.info("This process requires manual input on the Apple website.", emoji: "ℹ️")
        UI.info("Please follow the prompts in this terminal while navigating the webpage.", emoji: "👉")

        // 3. Preparation Task (Fetch draft and read files)
        let preparationTask = Task { () -> (appId: String, appName: String, codeContext: String)? in
            guard let service = try? Environment.live.asc(Environment.live.bezel) else { return nil }
            
            // For now, let's list apps and find draft version.
            guard let apps = try? await service.apps.listApps() else { return nil }
            var latestDraft: (app: AppInfo, version: String, id: String)?
            for app in apps {
                if let draft = try? await service.versions.findDraftVersion(for: app.id), draft.state == .prepareForSubmission {
                    latestDraft = (app, draft.version, draft.id)
                    break
                }
            }
            guard let draft = latestDraft else { return nil }

            let fileManager = FileManager.default
            var codeContext = ""
            var contextAppPath: String?
            
            let projectRoot = Environment.live.project.findProjectRoot()
            if let root = projectRoot,
               let config = try? Environment.live.project.loadConfig(at: root) {
                contextAppPath = config.appPath
            }

            let baseDir = projectRoot ?? URL(fileURLWithPath: fileManager.currentDirectoryPath)
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

        // 4. Analysis Task (Starts as soon as preparation is done)
        let analysisTask = Task { () -> DataCollectionAnalysis? in
            guard let prep = await preparationTask.value else { return nil }
            return try? await Environment.live.ai.analyzeDataCollection(appName: prep.appName, codeContext: prep.codeContext)
        }

        _ = UI.prompt("\nReady to open App Store Connect? [Press Enter]")

        // 5. Ensure preparation is complete before proceeding
        guard let prep = await preparationTask.value else {
            UI.error("Could not find an app version in 'Prepare for Submission' state.")
            UI.info("Please ensure you have an app version ready for submission in App Store Connect.", emoji: "👉")
            return
        }

        let appId = prep.appId
        let appStoreConnectPrivacyURL = "https://appstoreconnect.apple.com/apps/\(appId)/distribution/privacy"

        UI.info("Opening: \(appStoreConnectPrivacyURL)", emoji: "🌐")
        if let url = URL(string: appStoreConnectPrivacyURL) {
            UI.openURL(url)
        }
        
        // Wait for analysis result
        let analysis = await analysisTask.value

        print("\u{001B}[2J\u{001B}[H") // Clear screen
        UI.info("Assistant Mode Active: App Privacy Questionnaire", emoji: "🚀")
        print("-----------------------------------------------------------")
        print("1. Click 'Get Started' (or 'Edit' if you've started before) in the 'App Privacy' section.")
        print("2. Answer the first question:")
        print("   'Do you or your third-party partners collect data from this app?'")
        
        let recommendation = analysis?.collectsData ?? true
        if let analysis = analysis {
            print("   👉 Recommendation: Select '\(analysis.collectsData ? "Yes" : "No")'")
            print("   💡 Reasoning: \(analysis.reasoning)")
        } else {
            print("   Based on your knowledge, select 'Yes' or 'No'.")
        }
        
        let collectDataAnswer = UI.prompt("\n   What did you answer in App Store Connect?", defaultValue: recommendation ? "y" : "n").lowercased()

        let selectedNo = (recommendation && (collectDataAnswer == "n" || collectDataAnswer == "no")) ||
                         (!recommendation && (collectDataAnswer == "n" || collectDataAnswer == "no" || (collectDataAnswer.isEmpty && !recommendation)))

        if selectedNo {
            print("\u{001B}[2J\u{001B}[H") // Clear screen
            UI.success("App Privacy Questionnaire Guide Complete!")
            print("Since no data is collected, there are no further questions to answer.")
            print("Please review your selection on App Store Connect and click 'Publish'.")
            return
        }

        print("\u{001B}[2J\u{001B}[H") // Clear screen
        UI.info("Assistant Mode Active: App Privacy Questionnaire", emoji: "🚀")
        print("-----------------------------------------------------------")
        print("3. On the 'Data Collection' screen, you'll see various data types.")
        print("   For each data type, you need to indicate if you collect it.")
        
        if let analysis = analysis {
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
                print("   - No specific data types were identified after analysis.")
            } else {
                for type in identified {
                    print("   ✅ \(type)")
                }
            }
            print("\n   Select these types on the webpage and click 'Next'.")
        } else {
            print("   Refer to your own understanding of the app to select the data types.")
            print("   Commonly collected data types include 'Usage Data', 'Diagnostics', and 'Identifiers'.")
            print("   Once you've made all selections, click 'Next'.")
        }
        
        print("\n   Press Enter when you are done.")
        _ = UI.prompt("")
        
        print("\u{001B}[2J\u{001B}[H") // Clear screen
        UI.info("Assistant Mode Active: App Privacy Questionnaire", emoji: "🚀")
        print("-----------------------------------------------------------")
        print("4. For each data type you selected as 'Yes', you will now be asked:")
        print("   'Is all of the data collected from this app linked to the user’s identity?'")
        print("   Answer 'Yes' or 'No' as appropriate for each type. Many analytics services do link data.")
        print("   Press Enter when you have made your selections and clicked 'Next'.")
        _ = UI.prompt("")

        print("\u{001B}[2J\u{001B}[H") // Clear screen
        UI.info("Assistant Mode Active: App Privacy Questionnaire", emoji: "🚀")
        print("-----------------------------------------------------------")
        print("5. Next, for each data type, you will be asked:")
        print("   'Does all of the data collected from this app track the user?'")
        print("   This refers to tracking across apps and websites owned by other companies.")
        print("   Answer 'Yes' or 'No' as appropriate. If you use third-party analytics that track, select 'Yes'.")
        print("   Press Enter when you have made your selections and clicked 'Next'.")
        _ = UI.prompt("")

        print("\u{001B}[2J\u{001B}[H") // Clear screen
        UI.info("Assistant Mode Active: App Privacy Questionnaire", emoji: "🚀")
        print("-----------------------------------------------------------")
        print("6. Finally, for each data type, you will be asked:")
        print("   'Do you use the data to perform the following purposes?'")
        print("   Select all purposes that apply (e.g., 'App Functionality', 'Analytics', 'Product Personalization').")
        print("   Press Enter when you have made your selections and clicked 'Next'.")
        _ = UI.prompt("")

        print("\u{001B}[2J\u{001B}[H") // Clear screen
        UI.success("App Privacy Questionnaire Guide Complete!")
        print("Please review your answers on the App Store Connect website and click 'Publish'.")
        print("You can now close your browser and this terminal session for App Privacy.")
    }
}

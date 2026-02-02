import ArgumentParser
import Foundation

struct Screenshots: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "screenshots",
        abstract: "Generate and upload screenshots to App Store Connect."
    )

    @Option(name: .long, help: "The background color for the screenshots (HEX format).")
    var bg: String?

    func run() async throws {
        // 1. Get credentials
        guard let issuerId = ProcessInfo.processInfo.environment["APPSTORE_ISSUER_ID"],
              let keyId = ProcessInfo.processInfo.environment["APPSTORE_KEY_ID"],
              let privateKey = ProcessInfo.processInfo.environment["APPSTORE_PRIVATE_KEY"] else {
            print("❌ Error: Missing App Store Connect credentials.")
            return
        }

        let service = try AppStoreConnectService(issuerId: issuerId, keyId: keyId, privateKey: privateKey)

        print("📸 Generating App Store screenshots...")
        
        guard let draft = try await service.findLatestDraftVersion() else {
            print("❌ No app version in 'Prepare for Submission' state found.")
            return
        }

        // 2. Setup directory structure
        let rootDir = FileManager.default.currentDirectoryPath
        let releaseDir = URL(fileURLWithPath: rootDir).appendingPathComponent(".releases/\(draft.version)")
        let screenshotsDir = releaseDir.appendingPathComponent("screenshots")
        let iphoneDir = screenshotsDir.appendingPathComponent("iphone")
        let ipadDir = screenshotsDir.appendingPathComponent("ipad")
        let processedDir = screenshotsDir.appendingPathComponent("processed")

        let iphoneProcessedDir = processedDir.appendingPathComponent("iphone")
        let ipadProcessedDir = processedDir.appendingPathComponent("ipad")

        try FileManager.default.createDirectory(at: iphoneDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: ipadDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: iphoneProcessedDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: ipadProcessedDir, withIntermediateDirectories: true)

        // 3. Scan for screenshot files to determine filters
        var allImageFiles: [(url: URL, device: String)] = []
        for deviceType in ["iphone", "ipad"] {
            let deviceDir = deviceType == "iphone" ? iphoneDir : ipadDir
            if let files = try? FileManager.default.contentsOfDirectory(at: deviceDir, includingPropertiesForKeys: nil) {
                let images = files.filter { ["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) }
                allImageFiles.append(contentsOf: images.map { ($0, deviceType) })
            }
        }

        // 4. Handle Framefile.json and title.strings
        let framefileURL = screenshotsDir.appendingPathComponent("Framefile.json")
        let stringsURL = screenshotsDir.appendingPathComponent("title.strings")

        if !FileManager.default.fileExists(atPath: framefileURL.path) {
            print("📄 Generating default Framefile.json...")
            
            let defaultColor = bg ?? String(format: "%06X", Int.random(in: 0...0xFFFFFF))
            let defaultGradient = BackgroundGradient(start_color: defaultColor, end_color: defaultColor)
            
            let defaultKeywordConfig = TextConfiguration(font: "System", font_size: 80.0, color: "FFFFFF", weight: "bold")
            let defaultTitleConfig = TextConfiguration(font: "System", font_size: 80.0, color: "FFFFFF", weight: "regular")
            
            var dataConfigs: [ScreenshotConfig] = []
            var seenFilters = Set<String>()
            
            for (fileURL, _) in allImageFiles {
                let nameWithoutExtension = fileURL.deletingPathExtension().lastPathComponent
                let filter = nameWithoutExtension.split(separator: "-").last.map(String.init) ?? "default"
                
                if !seenFilters.contains(filter) {
                    dataConfigs.append(ScreenshotConfig(
                        filter: filter,
                        keyword: nil,
                        title: nil,
                        background_gradient: nil
                    ))
                    seenFilters.insert(filter)
                }
            }

            let framefile = Framefile(
                default_config: ScreenshotConfig(
                    filter: nil,
                    keyword: defaultKeywordConfig,
                    title: defaultTitleConfig,
                    background_gradient: defaultGradient
                ),
                data: dataConfigs
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(framefile)
            try data.write(to: framefileURL)
            print("Generated Framefile.json with placeholders.")
        }

        if !FileManager.default.fileExists(atPath: stringsURL.path) {
            print("📄 Generating default title.strings...")
            var stringsContent = ""
            var seenFilters = Set<String>()
            for (fileURL, _) in allImageFiles {
                let nameWithoutExtension = fileURL.deletingPathExtension().lastPathComponent
                let filter = nameWithoutExtension.split(separator: "-").last.map(String.init) ?? "default"
                if !seenFilters.contains(filter) {
                    stringsContent += "\"\(filter)\" = \"UPDATE ME: \(filter)\";\n"
                    seenFilters.insert(filter)
                }
            }
            if stringsContent.isEmpty {
                stringsContent = "// Add your screenshot titles here: \"filter_name\" = \"Title Text\";\n"
            }
            try stringsContent.write(to: stringsURL, atomically: true, encoding: .utf8)
            print("Generated title.strings with placeholders. Update it in \(stringsURL.path) to set the text for your screenshots.")
        }

        // 5. Process Images
        let processor = ImageProcessorService()
        let bezelService = BezelService()
        
        // Load Framefile
        let framefileData = try Data(contentsOf: framefileURL)
        let framefile = try JSONDecoder().decode(Framefile.self, from: framefileData)

        // Load title.strings
        let localizedStrings = loadStrings(from: stringsURL)

        for deviceType in ["iphone", "ipad"] {
            let deviceDir = deviceType == "iphone" ? iphoneDir : ipadDir
            let deviceProcessedDir = deviceType == "iphone" ? iphoneProcessedDir : ipadProcessedDir
            guard let bezelInfo = bezelService.bezelInfo(for: deviceType) else { continue }
            
            let files = try FileManager.default.contentsOfDirectory(at: deviceDir, includingPropertiesForKeys: nil)
            let imageFiles = files.filter { ["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) }

            if imageFiles.isEmpty {
                continue
            }

            print("🖼️ Framing \(deviceType) screenshots...")
            let bezelURL = try await bezelService.downloadBezelIfNeeded(for: bezelInfo)

            for file in imageFiles {
                let filename = file.lastPathComponent
                let nameWithoutExtension = file.deletingPathExtension().lastPathComponent
                let currentFilter = nameWithoutExtension.split(separator: "-").last.map(String.init) ?? "default"
                
                let outputURL = deviceProcessedDir.appendingPathComponent(filename)
                
                // Get config for this file from data array matching filter, or use global default
                let fileConfig = framefile.data?.first(where: { $0.filter == currentFilter }) ?? framefile.default_config
                
                // Resolve text from strings file using filter
                let filterToUse = fileConfig.filter ?? currentFilter
                let fullText = localizedStrings[filterToUse] ?? ""
                
                try processor.process(
                    screenshotURL: file,
                    bezelURL: bezelURL,
                    bezelInfo: bezelInfo,
                    config: fileConfig,
                    defaultConfig: framefile.default_config,
                    keywordText: "", // For now, we put everything in title
                    titleText: fullText,
                    outputURL: outputURL
                )
            }
        }

        // 6. Upload
        print("🚀 Uploading screenshots to App Store Connect...")
        try await service.uploadScreenshots(versionId: draft.id, processedDirectory: processedDir)
        print("✅ Screenshots uploaded successfully!")
    }

    private func loadStrings(from url: URL) -> [String: String] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        var result: [String: String] = [:]
        
        let pattern = "\"([^\"]+)\"\\s*=\\s*\"([^\"]+)\";"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let nsRange = NSRange(content.startIndex..<content.endIndex, in: content)
        
        regex?.enumerateMatches(in: content, options: [], range: nsRange) { match, _, _ in
            if let match = match,
               let keyRange = Range(match.range(at: 1), in: content),
               let valueRange = Range(match.range(at: 2), in: content) {
                let key = String(content[keyRange])
                let value = String(content[valueRange])
                result[key] = value
            }
        }
        
        return result
    }
}

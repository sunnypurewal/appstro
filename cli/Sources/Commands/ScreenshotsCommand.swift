import AppstroCore
import AppstroASC
import ArgumentParser
import Foundation
import CoreGraphics
import ImageIO

struct Screenshots: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "screenshots",
		abstract: "Generate and upload screenshots to App Store Connect."
	)

	@Option(name: .long, help: "The background color for the screenshots (HEX format).")
	var bg: String?

	@Option(name: .long, help: "The version to use (overrides automatic draft version detection).")
	var appVersion: String?

	@Option(name: .long, help: "Copy screenshots from this directory into the release folder and sort them.")
	var copy: String?

	func run() async throws {
		// 1. Find project root and config
		guard let root = Environment.live.project.findProjectRoot() else {
			UI.error("Not in an Appstro project. Run 'appstro init' first.")
			return
		}
		
		let config = try Environment.live.project.loadConfig(at: root)
		
		// 2. Setup ASC Service
		let service: any AppStoreConnectService
		do {
			service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
		} catch {
			UI.error("Failed to connect to App Store Connect: \(error.localizedDescription)")
			return
		}
		
		let query = Environment.live.queryInterpreter.interpret(config.name)
		let app: AppDetails? = try? await UI.step("Fetching app details", emoji: "🔍") {
			return try await service.apps.fetchAppDetails(query: query)
		}

		guard let app = app else {
			UI.error("Could not find app '\(config.name)' on App Store Connect.")
			return
		}

		let draft = try await service.versions.findDraftVersion(for: app.id)
		
		let versionString: String
		let versionId: String
		
		if let appVersion = appVersion {
			versionString = appVersion
			// If a version is explicitly provided, we try to match it with the draft
			if let draft = draft, draft.version == appVersion {
				versionId = draft.id
			} else {
				UI.error("Version \(appVersion) not found in draft state on App Store Connect.")
				return
			}
		} else if let draft = draft {
			versionString = draft.version
			versionId = draft.id
		} else {
			UI.error("No draft version found on App Store Connect. Use --app-version to specify a version.")
			return
		}

		// 3. Ensure Release Directory
		let releaseDir = try Environment.live.project.ensureReleaseDirectory(at: root, version: versionString)
		let screenshotsDir = releaseDir.appendingPathComponent("screenshots")
		let iphoneDir = screenshotsDir.appendingPathComponent("iphone")
		let ipadDir = screenshotsDir.appendingPathComponent("ipad")
		
		try FileManager.default.createDirectory(at: iphoneDir, withIntermediateDirectories: true)
		try FileManager.default.createDirectory(at: ipadDir, withIntermediateDirectories: true)

		// 4. Ensure Framefile and strings files exist
		let framefileURL = screenshotsDir.appendingPathComponent("Framefile.json")
		if !FileManager.default.fileExists(atPath: framefileURL.path) {
			let defaultBG = bg ?? "000000"
			let framefile = Framefile(
				default_config: ScreenshotConfig(
					filter: nil,
					keyword: nil,
					title: TextConfiguration(font: nil, font_size: nil, color: "FFFFFF", weight: "regular"),
					background_gradient: BackgroundGradient(start_color: defaultBG, end_color: defaultBG)
				),
				data: nil
			)
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			let data = try encoder.encode(framefile)
			try data.write(to: framefileURL)
		}

		let titleStringsURL = screenshotsDir.appendingPathComponent("title.strings")
		if !FileManager.default.fileExists(atPath: titleStringsURL.path) {
			let content = "\"example-1\" = \"Amazing Features\";\n\"example-2\" = \"Seamless Experience\";"
			try content.write(to: titleStringsURL, atomically: true, encoding: .utf8)
		}

		// 5. Handle --copy
		if let copyPath = copy {
			let newFiles: [URL] = try await UI.step("Analyzing, copying, and sorting screenshots", emoji: "📂") {
				let sourceURL = URL(fileURLWithPath: copyPath)
				let files = try FileManager.default.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: [.typeIdentifierKey])
				
				var usedKeywords: [String: Int] = [:]
				var createdFiles: [URL] = []

				for file in files {
					let ext = file.pathExtension.lowercased()
					guard ["png", "jpg", "jpeg"].contains(ext) else { continue }
					
					// A. Get semantic keyword from AI
					let description = try await Environment.live.ai.describeScreenshot(
						imageURL: file,
						appName: config.name,
						appDescription: config.description
					)
					var keyword = description.keyword
					
					// B. De-duplicate
					if let count = usedKeywords[keyword] {
						usedKeywords[keyword] = count + 1
						keyword = "\(keyword)-\(count + 1)"
					} else {
						usedKeywords[keyword] = 1
					}
					
                    // C. Detect size and aspect ratio
                    if let imageSource = CGImageSourceCreateWithURL(file as CFURL, nil),
                       let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
                       let width = imageProperties[kCGImagePropertyPixelWidth] as? CGFloat,
                       let height = imageProperties[kCGImagePropertyPixelHeight] as? CGFloat {
                        
                        let aspectRatio = max(width, height) / min(width, height)
                        let destinationDir = (aspectRatio < 1.6) ? ipadDir : iphoneDir
                        let destinationURL = destinationDir.appendingPathComponent("\(keyword).\(ext)")
                        
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try FileManager.default.removeItem(at: destinationURL)
                        }
                        try FileManager.default.copyItem(at: file, to: destinationURL)
						createdFiles.append(destinationURL)
                    }
				}
				return createdFiles
			}

			if !newFiles.isEmpty {
				var currentTitles = loadStrings(from: titleStringsURL)
				var newKeywords: [String] = []

				UI.info("Reviewing suggested titles for \(newFiles.count) screenshots...")
				
				for file in newFiles {
					let keyword = file.deletingPathExtension().lastPathComponent
					newKeywords.append(keyword)

					UI.openFile(file)
					
					let description = try await UI.step("Analyzing \(keyword)", emoji: "🔍") {
						return try await Environment.live.ai.describeScreenshot(
							imageURL: file,
							appName: config.name,
							appDescription: config.description
						)
					}
					
					let confirmedTitle = UI.prompt("Title for \(keyword)", defaultValue: description.title)
					UI.closeFile(file)
					
					currentTitles[keyword] = confirmedTitle
				}

				// Update metadata files
				let titleContent = currentTitles.map { "\"\($0.key)\" = \"\($0.value)\";" }.joined(separator: "\n")
				try titleContent.write(to: titleStringsURL, atomically: true, encoding: .utf8)
				
				// Update Framefile
				let framefileData = try Data(contentsOf: framefileURL)
				var framefile = try JSONDecoder().decode(Framefile.self, from: framefileData)
				var dataArray = framefile.data ?? []
				
				for k in newKeywords {
					if !dataArray.contains(where: { $0.filter == k }) {
						dataArray.append(ScreenshotConfig(
							filter: k,
							keyword: nil,
							title: nil,
							background_gradient: nil
						))
					}
				}
				
				framefile = Framefile(default_config: framefile.default_config, data: dataArray)
				let encoder = JSONEncoder()
				encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
				let encodedFramefile = try encoder.encode(framefile)
				try encodedFramefile.write(to: framefileURL)
			}
		}

		// 5. Verify screenshots exist
		let iphoneFiles = (try? FileManager.default.contentsOfDirectory(at: iphoneDir, includingPropertiesForKeys: nil)) ?? []
		let ipadFiles = (try? FileManager.default.contentsOfDirectory(at: ipadDir, includingPropertiesForKeys: nil)) ?? []
		
		if iphoneFiles.isEmpty && ipadFiles.isEmpty {
			UI.error("No screenshots found. Please pass in a directory containing screenshots using --copy <path_to_screenshots>")
			return
		}

		// 6. Process Screenshots
		let processedDir = releaseDir.appendingPathComponent("processed_screenshots")
		try? FileManager.default.removeItem(at: processedDir)
		try FileManager.default.createDirectory(at: processedDir, withIntermediateDirectories: true)

		let titles = loadStrings(from: titleStringsURL)
		
		let framefileData = try Data(contentsOf: framefileURL)
		let framefile = try JSONDecoder().decode(Framefile.self, from: framefileData)

		try await UI.step("Processing screenshots", emoji: "🎨") {
			for deviceType in ["iphone", "ipad"] {
				let sourceDir = screenshotsDir.appendingPathComponent(deviceType)
				let targetDir = processedDir.appendingPathComponent(deviceType)
				try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
				
				guard let bezelInfo = Environment.live.bezel.bezelInfo(for: deviceType) else { continue }
				let bezelURL = try await Environment.live.bezel.downloadBezelIfNeeded(for: bezelInfo)
				
				let files = (try? FileManager.default.contentsOfDirectory(at: sourceDir, includingPropertiesForKeys: nil)) ?? []
				let imageFiles = files.filter { ["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) }.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
				
				for file in imageFiles {
					let outputURL = targetDir.appendingPathComponent(file.lastPathComponent)
					let fileName = file.deletingPathExtension().lastPathComponent
					
					let specificConfig = framefile.data?.first(where: { $0.filter == fileName })
					
					try Environment.live.imageProcessor.process(
						screenshotURL: file,
						bezelURL: bezelURL,
						bezelInfo: bezelInfo,
						config: specificConfig ?? framefile.default_config,
						defaultConfig: framefile.default_config,
						keywordText: "",
						titleText: titles[fileName] ?? "",
						outputURL: outputURL
					)
				}
			}
		}

		// 7. Upload to App Store Connect
		try await UI.step("Uploading to version \(versionString)", emoji: "🚀") {
			try await service.screenshots.uploadScreenshots(versionId: versionId, processedDirectory: processedDir)
		}
		
		UI.success("Screenshots uploaded successfully!")
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

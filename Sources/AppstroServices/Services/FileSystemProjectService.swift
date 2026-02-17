import AppstroCore
import Foundation
import XcodeProj
import PathKit

public final class FileSystemProjectService: ProjectService {
	public static let shared = FileSystemProjectService()
	
	public init() {}
	
	public func findProjectRoot() -> URL? {
		let fileManager = FileManager.default
		var currentDir = URL(fileURLWithPath: fileManager.currentDirectoryPath)
		
		for _ in 0...5 {
			let checkURL = currentDir.appendingPathComponent("appstro.json")
			if fileManager.fileExists(atPath: checkURL.path) {
				return currentDir
			}
			let parentDir = currentDir.deletingLastPathComponent()
			if parentDir == currentDir { break }
			currentDir = parentDir
		}
		
		return nil
	}
	
	public func loadConfig(at root: URL) throws -> AppstroConfig {
		let configURL = root.appendingPathComponent("appstro.json")
		let data = try Data(contentsOf: configURL)
		return try JSONDecoder().decode(AppstroConfig.self, from: data)
	}

	public func saveConfig(_ config: AppstroConfig, at root: URL) throws {
		let configURL = root.appendingPathComponent("appstro.json")
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		let data = try encoder.encode(config)
		try data.write(to: configURL)
	}

	public func containsXcodeProject(at url: URL) -> String? {
		let fileManager = FileManager.default
		guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
			return nil
		}
		
		#if DEBUG
		print("Checking directory: \(url.path)")
		print("Contents: \(contents.map { $0.lastPathComponent })")
		#endif

		if let project = contents.first(where: { $0.pathExtension == "xcodeproj" }) {
			return project.deletingPathExtension().lastPathComponent
		}
		
		if let workspace = contents.first(where: { $0.pathExtension == "xcworkspace" }) {
			return workspace.deletingPathExtension().lastPathComponent
		}
		
		return nil
	}

	public func getBundleIdentifier(at url: URL) -> String? {
		let fileManager = FileManager.default
		guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
			return nil
		}

		guard let projectPath = contents.first(where: { $0.pathExtension == "xcodeproj" }) else {
			return nil
		}

		do {
			let xcodeProj = try XcodeProj(path: Path(projectPath.path))
			let pbxproj = xcodeProj.pbxproj

			// Try to find the bundle identifier in the build settings of the first application target
			for target in pbxproj.nativeTargets {
				guard target.productType == .application else { continue }
				
				for buildConfiguration in target.buildConfigurationList?.buildConfigurations ?? [] {
					if let bundleID = buildConfiguration.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] as? String {
						// Basic check to see if it's not a variable (like $(PRODUCT_BUNDLE_IDENTIFIER))
						// though usually PRODUCT_BUNDLE_IDENTIFIER *is* the key we want.
						if !bundleID.starts(with: "$(") {
							return bundleID
						}
					}
				}
			}
			
						// If not found in targets, check project build settings
			
						for buildConfiguration in pbxproj.projects.first?.buildConfigurationList?.buildConfigurations ?? [] {
			
							if let bundleID = buildConfiguration.buildSettings["PRODUCT_BUNDLE_IDENTIFIER"] as? String {
			
								if !bundleID.starts(with: "$(") {
			
									return bundleID
			
								}
			
							}
			
						}
			
					} catch {
			
						#if DEBUG
			
						print("Error reading Xcode project: \(error)")
			
						#endif
			
					}
			
			
			
					// Fallback: search for Info.plist files
			
					let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsPackageDescendants, .skipsHiddenFiles])
			
					while let fileURL = enumerator?.nextObject() as? URL {
			
						if fileURL.lastPathComponent == "Info.plist" {
			
							if let dict = NSDictionary(contentsOf: fileURL),
			
							   let bundleID = dict["CFBundleIdentifier"] as? String,
			
							   !bundleID.starts(with: "$(") {
			
								return bundleID
			
							}
			
						}
			
					}
			
			
			
					return nil
			
				}

	public func getTeamID(at url: URL) -> String? {
		let fileManager = FileManager.default
		guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
			return nil
		}

		guard let projectPath = contents.first(where: { $0.pathExtension == "xcodeproj" }) else {
			return nil
		}

		do {
			let xcodeProj = try XcodeProj(path: Path(projectPath.path))
			let pbxproj = xcodeProj.pbxproj

			for target in pbxproj.nativeTargets {
				guard target.productType == .application else { continue }
				
				for buildConfiguration in target.buildConfigurationList?.buildConfigurations ?? [] {
					if let teamID = buildConfiguration.buildSettings["DEVELOPMENT_TEAM"] as? String {
						if !teamID.starts(with: "$(") {
							return teamID
						}
					}
				}
			}
			
			for buildConfiguration in pbxproj.projects.first?.buildConfigurationList?.buildConfigurations ?? [] {
				if let teamID = buildConfiguration.buildSettings["DEVELOPMENT_TEAM"] as? String {
					if !teamID.starts(with: "$(") {
						return teamID
					}
				}
			}
		} catch {
			#if DEBUG
			print("Error reading Xcode project for team ID: \(error)")
			#endif
		}

		return nil
	}

	public func ensureAppstroDirectory(at root: URL) async throws -> URL {
		let appstroURL = root.appendingPathComponent(".appstro")
		if !FileManager.default.fileExists(atPath: appstroURL.path) {
			try FileManager.default.createDirectory(at: appstroURL, withIntermediateDirectories: true)
			try? await setupGitIgnore(at: root)
		}
		return appstroURL
	}

	public func ensureReleaseDirectory(at root: URL, version: String) async throws -> URL {
		let appstroURL = try await ensureAppstroDirectory(at: root)
		let releaseURL = appstroURL.appendingPathComponent("releases").appendingPathComponent(version)
		if !FileManager.default.fileExists(atPath: releaseURL.path) {
			try FileManager.default.createDirectory(at: releaseURL, withIntermediateDirectories: true)
		}
		return releaseURL
	}

	public func setupGitIgnore(at root: URL) async throws {
		let gitignoreURL = root.appendingPathComponent(".gitignore")
		let entry = ".appstro/"
		let swiftGitignoreURL = URL(string: "https://raw.githubusercontent.com/github/gitignore/refs/heads/main/Swift.gitignore")!

		let fileManager = FileManager.default
		if fileManager.fileExists(atPath: gitignoreURL.path) {
			var content = try String(contentsOf: gitignoreURL, encoding: .utf8)
			let lines = content.components(separatedBy: .newlines)
			if !lines.contains(entry) && !lines.contains(".appstro") {
				if !content.isEmpty && !content.hasSuffix("\n") {
					content += "\n"
				}
				content += entry + "\n"
				try content.write(to: gitignoreURL, atomically: true, encoding: .utf8)
			}
		} else {
			do {
				let (data, _) = try await URLSession.shared.data(from: swiftGitignoreURL)
				var content = String(data: data, encoding: .utf8) ?? ""
				if !content.isEmpty && !content.hasSuffix("\n") {
					content += "\n"
				}
				content += "\n# Appstro\n"
				content += entry + "\n"
				try content.write(to: gitignoreURL, atomically: true, encoding: .utf8)
			} catch {
				// Fallback if download fails
				try (entry + "\n").write(to: gitignoreURL, atomically: true, encoding: .utf8)
			}
		}
	}

	public func initializeGit(at root: URL) async throws {
		let gitURL = root.appendingPathComponent(".git")
		if !FileManager.default.fileExists(atPath: gitURL.path) {
			let process = Process()
			process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
			process.currentDirectoryURL = root
			process.arguments = ["init"]
			try await runProcess(process)
		}
	}

	public func build(at root: URL, config: AppstroConfig, version: String, buildNumber: String) async throws -> URL {
		let appPath = config.appPath ?? "."
		let projectURL = root.appendingPathComponent(appPath)
		
		guard let projectName = containsXcodeProject(at: projectURL) else {
			throw NSError(domain: "BuildError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No Xcode project or workspace found at \(appPath)."])
		}
		
		let isWorkspace = FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("\(projectName).xcworkspace").path)
		let projectArgument = isWorkspace ? "-workspace" : "-project"
		let projectPath = isWorkspace ? "\(projectName).xcworkspace" : "\(projectName).xcodeproj"
		
		let releaseDir = try await ensureReleaseDirectory(at: root, version: version)
		let archivePath = releaseDir.appendingPathComponent("\(projectName).xcarchive").path
		let exportPath = releaseDir.path
		let ipaPath = releaseDir.appendingPathComponent("\(projectName).ipa")
		
		// 1. Archive
		let archiveProcess = Process()
		archiveProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
		archiveProcess.currentDirectoryURL = projectURL
		archiveProcess.arguments = [
			"archive",
			projectArgument, projectPath,
			"-scheme", projectName,
			"-configuration", "Release",
			"-archivePath", archivePath,
			"-allowProvisioningUpdates",
			"CURRENT_PROJECT_VERSION=\(buildNumber)"
		]
		
		try await runProcess(archiveProcess)
		
		// 2. Export
		let exportOptionsURL = releaseDir.appendingPathComponent("ExportOptions.plist")
		try createExportOptionsPlist(at: exportOptionsURL, config: config)
		
		let exportProcess = Process()
		exportProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
		exportProcess.currentDirectoryURL = projectURL
		exportProcess.arguments = [
			"-exportArchive",
			"-archivePath", archivePath,
			"-exportOptionsPlist", exportOptionsURL.path,
			"-exportPath", exportPath,
			"-allowProvisioningUpdates"
		]
		
		try await runProcess(exportProcess)
		
		// Rename if necessary (xcodebuild often exports to Scheme.ipa)
		let exportedIPA = releaseDir.appendingPathComponent("\(projectName).ipa")
		if !FileManager.default.fileExists(atPath: exportedIPA.path) {
			// Try to find any IPA in the export directory
			let contents = try FileManager.default.contentsOfDirectory(at: releaseDir, includingPropertiesForKeys: nil)
			if let foundIPA = contents.first(where: { $0.pathExtension == "ipa" }) {
				try FileManager.default.moveItem(at: foundIPA, to: exportedIPA)
			}
		}
		
		return exportedIPA
	}

	private func runProcess(_ process: Process) async throws {
		let pipe = Pipe()
		process.standardOutput = pipe
		process.standardError = pipe
		
		try process.run()
		
		let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
		process.waitUntilExit()
		
		if process.terminationStatus != 0 {
			if let output = String(data: data, encoding: .utf8) {
				print(output)
			}
			throw NSError(domain: "BuildError", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "xcodebuild failed with exit code \(process.terminationStatus)"])
		}
	}

	private func createExportOptionsPlist(at url: URL, config: AppstroConfig) throws {
		var plist: [String: Any] = [
			"method": "app-store-connect",
			"signingStyle": "automatic",
			"uploadBitcode": false,
			"uploadSymbols": true,
			"manageAppVersionAndBuildNumber": true
		]
		if let teamID = config.teamID {
			plist["teamID"] = teamID
		}
		let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
		try data.write(to: url)
	}
}
			
			
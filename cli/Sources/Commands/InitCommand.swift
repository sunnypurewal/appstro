import AppstroCore
import ArgumentParser
import Foundation
import XcodeGenKit
import ProjectSpec
import PathKit
import XcodeProj

struct Init: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "init",
		abstract: "Initialize a new iOS project."
	)

	@Argument(help: "The path to initialize the project in.")
	var path: String = "."

	func run() async throws {
		let currentPath = Path.current
		let projectPath = (Path(path).isAbsolute ? Path(path) : currentPath + path).normalize()

		if !projectPath.exists {
			try projectPath.mkpath()
		}

		let projectURL = URL(fileURLWithPath: projectPath.string, isDirectory: true)
		let existingProjectName = Environment.live.project.containsXcodeProject(at: projectURL)
		let existingBundleIdentifier = Environment.live.project.getBundleIdentifier(at: projectURL)

		if (projectPath + "appstro.json").exists {
			let overwrite = prompt("appstro.json already exists. Overwrite?", default: "no")
			if overwrite.lowercased() != "yes" && overwrite.lowercased() != "y" {
				print("Aborted.")
				return
			}
		}

		print("This utility will walk you through creating an appstro.json file.")
		print("It only covers the most common items, and tries to guess sensible defaults.")
		print("")
		print("See `appstro help init` for definitive documentation on these fields")
		print("and exactly what they do.")
		print("")
		print("Press ^C at any time to quit.")
		print("")

		let defaultName = existingProjectName ?? projectPath.lastComponent
		let projectName = prompt("app name", default: defaultName)
		let description = prompt("description")
		let keywordsString = prompt("keywords")
		let keywords = keywordsString.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
		
		let bundleIdentifier = existingBundleIdentifier
		let teamID = prompt("team id (optional, for code signing)")

		let config = AppstroConfig(
			name: projectName,
			description: description,
			keywords: keywords,
			bundleIdentifier: bundleIdentifier,
			appPath: ".",
			teamID: teamID.isEmpty ? nil : teamID
		)

		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		let configData = try encoder.encode(config)
		let configJson = String(data: configData, encoding: .utf8) ?? "{}"

		print("\nAbout to write to \((projectPath + "appstro.json").string):\n")
		print(configJson)
		print("")

		let ok = prompt("Is this OK?", default: "yes")
		if ok.lowercased() != "yes" && ok.lowercased() != "y" {
			print("Aborted.")
			return
		}

		let xcodeProjectPath = projectPath + "\(projectName).xcodeproj"

		try await UI.step("Initializing project", emoji: "🚀") {
			// 1. Write appstro.json
			try (projectPath + "appstro.json").write(configData)

			// 2. Setup .gitignore
			try await Environment.live.project.setupGitIgnore(at: projectURL)

			if existingProjectName == nil {
				// 2. Create directories
				let sourcesPath = projectPath + "Sources"
				try sourcesPath.mkpath()

				// 3. Create basic SwiftUI files
				let appSwift = """
				import SwiftUI	

				@main
				struct \(projectName)App: App {
					var body: some Scene {
						WindowGroup {
							ContentView()
						}
					}
				}
				"""

				let contentViewSwift = """
				import SwiftUI

				struct ContentView: View {
					var body: some View {
						VStack {
							Image(systemName: "globe")
								.imageScale(.large)
								.foregroundStyle(.tint)
							Text("Hello, \(projectName)!")
						}
						.padding()
					}
				}
				"""

				try (sourcesPath + "App.swift").write(appSwift)
				try (sourcesPath + "ContentView.swift").write(contentViewSwift)

				// 4. Define Project using XcodeGen
				let buildSettings: [String: Any] = [
					"PRODUCT_BUNDLE_IDENTIFIER": bundleIdentifier ?? "com.appstro.placeholder",
					"IPHONEOS_DEPLOYMENT_TARGET": "16.0",
					"TARGETED_DEVICE_FAMILY": "1", // iPhone
					"GENERATE_INFOPLIST_FILE": "YES",
					"MARKETING_VERSION": "1.0",
					"CURRENT_PROJECT_VERSION": "1",
					"SWIFT_VERSION": "5.9",
					"INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
					"INFOPLIST_KEY_UISupportedInterfaceOrientations": "UIInterfaceOrientationPortrait",
				]

				let target = Target(
					name: projectName,
					type: .application,
					platform: .iOS,
					deploymentTarget: "16.0",
					settings: Settings(buildSettings: buildSettings),
					sources: [TargetSource(path: "Sources")]
				)

				let project = Project(
					basePath: projectPath,
					name: projectName,
					configs: [
						Config(name: "Debug", type: .debug),
						Config(name: "Release", type: .release)
					],
					targets: [target],
					options: SpecOptions(xcodeVersion: "16.0")
				)

				// 5. Generate Xcode Project
				let generator = ProjectGenerator(project: project)
				let xcodeProject = try generator.generateXcodeProject(userName: NSFullUserName())
				
				// Manually set latest compatibility and object versions for Xcode 16
				xcodeProject.pbxproj.rootObject?.compatibilityVersion = "Xcode 16.0"
				xcodeProject.pbxproj.rootObject?.attributes["LastUpgradeCheck"] = "1600"
				xcodeProject.pbxproj.rootObject?.preferredProjectObjectVersion = 77
				
				if xcodeProjectPath.exists {
					let overwrite = prompt("\(xcodeProjectPath.lastComponent) already exists. Overwrite?", default: "no")
					if overwrite.lowercased() == "yes" || overwrite.lowercased() == "y" {
						try xcodeProject.write(path: xcodeProjectPath)
					} else {
						print("Skipping Xcode project generation. You may need to manually configure your project to work with appstro.")
					}
				} else {
					try xcodeProject.write(path: xcodeProjectPath)
				}
			}
		}
		
		UI.success("Initialization Complete")
	}

	private func prompt(_ text: String, default defaultValue: String? = nil) -> String {
		let defaultSuffix = defaultValue != nil ? ": (\(defaultValue!))" : ":"
		print("\(text)\(defaultSuffix) ", terminator: "")
		fflush(stdout)
		let input = readLine() ?? ""
		return input.isEmpty ? (defaultValue ?? "") : input
	}
}
import AppstroCore
import AppstroASC
import ArgumentParser
import Foundation

struct Create: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "create",
		abstract: "Create a new app in App Store Connect."
	)

	@Argument(help: "The name of the app to create.")
	var name: String

	@Option(name: .long, help: "The bundle identifier prefix (e.g., com.example). If not provided, we will try to deduce it.")
	var bundleIdPrefix: String?

	func run() async throws {
		// 1. Get credentials and service
		let service: any AppStoreConnectService
		do {
			service = try Environment.live.asc(Environment.live.bezel)
		} catch {
			UI.error("\(error.localizedDescription)")
			return
		}

		let description = UI.prompt("📝 Enter a brief description/pitch for '\(name)'")

		// 2. Identify/Deduce Prefix
		let prefix: String
		do {
			prefix = try await UI.step("Deducing bundle ID prefix", emoji: "🔍") {
				guard let prefix = try await service.bundleIds.deduceBundleIdPrefix(preferredPrefix: bundleIdPrefix) else {
					throw NSError(domain: "CreateError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Could not deduce a bundle ID prefix. Please provide one with --bundle-id-prefix."])
				}
				return prefix
			}
		} catch {
			return
		}
		
		let bundleId = "\(prefix).\(name.lowercased().replacingOccurrences(of: " ", with: "-"))"
		UI.info("Using Bundle ID: \(bundleId)", emoji: "📦")

		// 3. Register Bundle ID
		do {
			try await UI.step("Registering Bundle ID '\(bundleId)'", emoji: "🚀") {
				_ = try await service.bundleIds.registerBundleId(name: name, identifier: bundleId)
			}
		} catch {
			return
		}

		// 4. Update project config
		if let root = Environment.live.project.findProjectRoot() {
			try? await UI.step("Updating project configuration", emoji: "📝") {
				let configPath = root.appendingPathComponent("appstro.json")
				if FileManager.default.fileExists(atPath: configPath.path) {
					let oldConfig = try Environment.live.project.loadConfig(at: root)
					let newConfig = AppstroConfig(
						name: oldConfig.name,
						description: description.isEmpty ? oldConfig.description : description,
						keywords: oldConfig.keywords,
						bundleIdentifier: bundleId,
						appPath: oldConfig.appPath
					)
					let encoder = JSONEncoder()
					encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
					let data = try encoder.encode(newConfig)
					try data.write(to: configPath)
				}
			}
		}
		
		UI.success("App '\(name)' is ready for development! 🎉")
		UI.info("Next: run 'appstro metadata' to generate app store info.", emoji: "👉")
	}
}
import AppstroCore
import AppstroASC
import ArgumentParser
import Foundation

struct Profile: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "profile",
		abstract: "Manage provisioning profiles.",
		subcommands: [CreateProfile.self]
	)
}

struct CreateProfile: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "create",
		abstract: "Create a new iOS App Store provisioning profile for the current app."
	)

	func run() async throws {
		// 1. Get service
		let service: any AppStoreConnectService
		do {
			service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
		} catch {
			UI.error("\(error.localizedDescription)")
			return
		}

		// 2. Locate project root and config
		guard let projectRoot = Environment.live.project.findProjectRoot() else {
			UI.error("Could not find project root (appstro.json).")
			return
		}

		let config = try Environment.live.project.loadConfig(at: projectRoot)
		let appName = config.name
		
		// 3. Find App
		let appInfo: AppInfo
		do {
			appInfo = try await UI.step("Finding app '\(appName)'", emoji: "🔍") {
				let apps = try await service.apps.listApps()
				guard let appInfo = apps.first(where: { $0.name.localizedCaseInsensitiveCompare(appName) == .orderedSame }) else {
					throw NSError(domain: "ProfileError", code: 404, userInfo: [NSLocalizedDescriptionKey: "App '\(appName)' not found in your App Store Connect account."])
				}
				return appInfo
			}
		} catch {
			return
		}
		let bundleId = appInfo.bundleId
		UI.info("Found Bundle ID: \(bundleId)", emoji: "📦")

		// 4. Get Distribution Certificate & Bundle ID Record ID
		let (certId, bundleIdRecordId): (String, String)
		do {
			(certId, bundleIdRecordId) = try await UI.step("Searching for Distribution Certificate and Bundle ID record", emoji: "🔍") {
				let certId = try await service.certificates.findDistributionCertificateId()
				let bundleIdRecordId = try await service.bundleIds.findBundleIdRecordId(identifier: bundleId)
				return (certId, bundleIdRecordId)
			}
		} catch {
			return
		}

		// 6. Create Profile
		let profileName = "\(appName) App Store Distribution"
		let profileData: Data
		do {
			profileData = try await UI.step("Creating provisioning profile: \(profileName)", emoji: "🚀") {
				return try await service.certificates.createProvisioningProfile(
					name: profileName,
					bundleIdRecordId: bundleIdRecordId,
					certificateId: certId
				)
			}
		} catch {
			return
		}

		// 7. Save Profile
		let profileFileName = "\(appName).mobileprovision"
		let profileURL = projectRoot.appendingPathComponent(profileFileName)
		try profileData.write(to: profileURL)

		UI.success("Provisioning profile created")
	}
}

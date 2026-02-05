import AppstroCore
import AppstroASC
import ArgumentParser
import Foundation

struct Upload: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "upload",
		abstract: "Upload an IPA file to App Store Connect and attach it to the draft version."
	)

	@Argument(help: "The path to the IPA file.")
	var ipaPath: String

	func run() async throws {
		// 1. Get service
		let service: any AppStoreConnectService
		do {
			service = try ASCServiceFactory.makeService(bezelService: Environment.live.bezel)
		} catch {
			UI.error("\(error.localizedDescription)")
			return
		}
		
		// Credentials for altool
		guard let issuerId = ProcessInfo.processInfo.environment["APPSTORE_ISSUER_ID"],
			  let keyId = ProcessInfo.processInfo.environment["APPSTORE_KEY_ID"],
			  let privateKey = ProcessInfo.processInfo.environment["APPSTORE_PRIVATE_KEY"] else {
			UI.error("Missing App Store Connect credentials.")
			return
		}

		// 2. Validate IPA exists
		let ipaURL = URL(fileURLWithPath: ipaPath)
		guard FileManager.default.fileExists(atPath: ipaURL.path) else {
			UI.error("IPA file not found at \(ipaPath)")
			return
		}

		// 3. Find latest draft version
		let draft: (app: AppInfo, version: String, id: String)
		do {
			draft = try await UI.step("Fetching draft version from App Store Connect", emoji: "🔍") {
				let apps = try await service.apps.listApps()
				let submittableStates: Set<AppVersionState> = [.prepareForSubmission, .rejected, .metadataRejected, .developerRejected]
				for app in apps {
					if let draft = try await service.versions.findDraftVersion(for: app.id), submittableStates.contains(draft.state) {
						return (app: app, version: draft.version, id: draft.id)
					}
				}
				throw NSError(domain: "UploadError", code: 404, userInfo: [NSLocalizedDescriptionKey: "No app version in a submittable state (Prepare for Submission, Rejected, etc.) found."])
			}
		} catch {
			return
		}
		UI.info("Target version: \(draft.version) (App: \(draft.app.name))", emoji: "📦")

		// Get the latest build ID before uploading to ensure we wait for the NEW build
		let existingBuilds = try await service.versions.fetchBuilds(appId: draft.app.id, version: draft.version)
		let latestBuildIdBefore = existingBuilds.first?.id

		// 4. Upload IPA
		do {
			try await UI.step("Uploading IPA to App Store Connect", emoji: "🚀") {
				try await uploadIPA(ipaURL: ipaURL, issuerId: issuerId, keyId: keyId, privateKey: privateKey)
			}
		} catch {
			return
		}

		// 5. Wait for processing
		let build: BuildInfo
		do {
			build = try await UI.step("Waiting for Apple to process the build (this can take several minutes)", emoji: "⏳") {
				return try await waitForBuild(service: service, appId: draft.app.id, version: draft.version, latestBuildIdBefore: latestBuildIdBefore)
			}
		} catch {
			return
		}
		UI.success("Build \(build.version) (\(build.id)) is ready!")

		// 6. Attach build to version
		do {
			try await UI.step("Attaching build to version \(draft.version)", emoji: "🔗") {
				try await service.versions.attachBuildToVersion(versionId: draft.id, buildId: build.id)
			}
			UI.success("Build attached to submission successfully!")
		} catch {
			return
		}
	}

	private func uploadIPA(ipaURL: URL, issuerId: String, keyId: String, privateKey: String) async throws {
		let homeDir = FileManager.default.homeDirectoryForCurrentUser
		let keyDir = homeDir.appendingPathComponent(".appstoreconnect/private_keys")
		let keyFile = keyDir.appendingPathComponent("AuthKey_\(keyId).p8")

		// Create directory if it doesn't exist
		try FileManager.default.createDirectory(at: keyDir, withIntermediateDirectories: true)
		
		// Write the key
		try privateKey.write(to: keyFile, atomically: true, encoding: .utf8)
		defer { try? FileManager.default.removeItem(at: keyFile) }

		let process = Process()
		process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
		process.arguments = [
			"altool",
			"--upload-app",
			"-f", ipaURL.path,
			"-t", "ios",
			"--apiKey", keyId,
			"--apiIssuer", issuerId,
			"--verbose"
		]

		let pipe = Pipe()
		process.standardOutput = pipe
		process.standardError = pipe

		try process.run()
		
		let data = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
		process.waitUntilExit()

		let output = String(data: data, encoding: .utf8) ?? ""
		
		// altool returns 0 on success, but we should also check the output for confirmation
		let isSuccess = process.terminationStatus == 0 && (output.contains("No errors") || output.contains("Upload done"))
		
		if !isSuccess {
			if !output.isEmpty {
				print(output)
			}
			throw NSError(domain: "UploadError", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "IPA upload failed. Check the output above for details."])
		}
	}

	private func waitForBuild(service: any AppStoreConnectService, appId: String, version: String, latestBuildIdBefore: String?) async throws -> BuildInfo {
		let start = Date()
		let timeout: TimeInterval = 60 * 20 // 20 minutes timeout
		
		while Date().timeIntervalSince(start) < timeout {
			let builds = try await service.versions.fetchBuilds(appId: appId, version: version)
			
			// Look for a build that is NOT the one we already had
			if let build = builds.first, build.id != latestBuildIdBefore {
				let state = build.processingState
				
				if state == .valid {
					return build
				} else if state != .processing {
					// Any state other than VALID or PROCESSING is considered a failure/termination
					let message = state == .failed || state == .invalid ? 
						"Apple rejected the build (State: \(state.rawValue)). Check App Store Connect for details." :
						"Build processing finished with unexpected state: \(state.rawValue)"
					throw NSError(domain: "UploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
				}
				// If it's .processing, we continue waiting
			}
			
			try? await Task.sleep(nanoseconds: 30 * 1_000_000_000) // Poll every 30 seconds
		}
		
		throw NSError(domain: "UploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for build to process."])
	}
}

import ArgumentParser
import Foundation
import AppStoreConnect_Swift_SDK

struct Upload: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "upload",
        abstract: "Upload an IPA file to App Store Connect and attach it to the draft version."
    )

    @Argument(help: "The path to the IPA file.")
    var ipaPath: String

    func run() async throws {
        // 1. Get credentials
        guard let issuerId = ProcessInfo.processInfo.environment["APPSTORE_ISSUER_ID"],
              let keyId = ProcessInfo.processInfo.environment["APPSTORE_KEY_ID"],
              let privateKey = ProcessInfo.processInfo.environment["APPSTORE_PRIVATE_KEY"] else {
            print("❌ Error: Missing App Store Connect credentials.")
            return
        }

        let service = try AppStoreConnectService(issuerId: issuerId, keyId: keyId, privateKey: privateKey)

        // 2. Validate IPA exists
        let ipaURL = URL(fileURLWithPath: ipaPath)
        guard FileManager.default.fileExists(atPath: ipaURL.path) else {
            print("❌ Error: IPA file not found at \(ipaPath)")
            return
        }

        // 3. Find latest draft version
        print("🔍 Fetching draft version from App Store Connect...")
        guard let draft = try await service.findLatestDraftVersion() else {
            print("❌ Error: No app version in 'Prepare for Submission' state found.")
            return
        }
        print("📦 Target version: \(draft.version) (App: \(draft.app.name))")

        // 4. Upload IPA
        print("🚀 Uploading IPA to App Store Connect...")
        try await uploadIPA(ipaURL: ipaURL, issuerId: issuerId, keyId: keyId, privateKey: privateKey)
        print("✅ IPA uploaded successfully!")

        // 5. Wait for processing
        print("⏳ Waiting for Apple to process the build (this can take several minutes)...")
        let build = try await waitForBuild(service: service, appId: draft.app.id, version: draft.version)
        print("✅ Build \(build.attributes?.version ?? "unknown") (\(build.id)) is ready!")

        // 6. Attach build to version
        print("🔗 Attaching build to version \(draft.version)...")
        try await service.attachBuildToVersion(versionId: draft.id, buildId: build.id)
        print("✅ Build attached to submission successfully!")
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
            "--apiIssuer", issuerId
        ]

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
            throw NSError(domain: "UploadError", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "IPA upload failed with exit code \(process.terminationStatus)"])
        }
    }

    private func waitForBuild(service: AppStoreConnectService, appId: String, version: String) async throws -> AppStoreConnect_Swift_SDK.Build {
        let start = Date()
        let timeout: TimeInterval = 60 * 20 // 20 minutes timeout
        
        while Date().timeIntervalSince(start) < timeout {
            let builds = try await service.fetchBuilds(appId: appId, version: version)
            
            // Look for a build that is NOT in 'FAILED' state and has finished processing
            // Processing state is usually indicated by the presence of the build and its state
            if let build = builds.first {
                let state = build.attributes?.processingState
                
                if state == .valid {
                    return build
                } else if state == .invalid {
                    throw NSError(domain: "UploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Apple rejected the build. Check App Store Connect for details."])
                }
                
                // Still processing
                print("   ...processing (\(state?.rawValue ?? "unknown"))...")
            } else {
                print("   ...waiting for build to appear...")
            }
            
            try? await Task.sleep(nanoseconds: 30 * 1_000_000_000) // Poll every 30 seconds
        }
        
        throw NSError(domain: "UploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for build to process."])
    }
}

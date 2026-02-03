import ArgumentParser
import Foundation

struct Build: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "build",
        abstract: "Build the RELEASE configuration of the app for App Store submission."
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

        let service = try AppStoreConnectService(issuerId: issuerId, keyId: keyId, privateKey: privateKey)
        let projectService = ProjectService.shared

        // 2. Locate project root and config
        guard let projectRoot = projectService.findProjectRoot() else {
            print("❌ Error: Could not find project root. Ensure appstro.json exists in the current or parent directory.")
            return
        }

        let config = try projectService.loadConfig(at: projectRoot)
        let appName = config.name
        let appPath = config.appPath ?? ""
        let projectDir = projectRoot.appendingPathComponent(appPath)
        let xcodeProjectPath = projectDir.appendingPathComponent("\(appName).xcodeproj")

        // 3. Fetch latest draft version for path naming
        print("🔍 Fetching draft version from App Store Connect...")
        guard let draft = try await service.findLatestDraftVersion() else {
            print("❌ Error: No app version in 'Prepare for Submission' state found on App Store Connect.")
            return
        }
        let version = draft.version
        print("📦 Target version: \(version)")

        // 4. Prepare directories
        let releasesDir = projectRoot.appendingPathComponent(".releases").appendingPathComponent(version)
        let buildDir = releasesDir.appendingPathComponent("build")
        
        try FileManager.default.createDirectory(at: buildDir, withIntermediateDirectories: true)

        let archivePath = buildDir.appendingPathComponent("\(appName).xcarchive")
        let exportOptionsPath = buildDir.appendingPathComponent("ExportOptions.plist")
        let keyPath = buildDir.appendingPathComponent("AuthKey_\(keyId).p8")

        // 5. Write private key to file for xcodebuild authentication
        print("🔐 Preparing authentication key...")
        try privateKey.write(to: keyPath, atomically: true, encoding: .utf8)

        // 6. Generate ExportOptions.plist
        print("📝 Generating Export Options...")
        let exportOptions: [String: Any] = [
            "method": "app-store-connect",
            "destination": "export",
            "manageAppVersionAndBuildNumber": true,
            "signingStyle": "automatic"
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: exportOptions, format: .xml, options: 0)
        try plistData.write(to: exportOptionsPath)

        // 7. Archive
        print("🏗️ Archiving \(appName)...")
        let archiveProcess = Process()
        archiveProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        archiveProcess.arguments = [
            "archive",
            "-project", xcodeProjectPath.path,
            "-scheme", appName,
            "-configuration", "Release",
            "-destination", "generic/platform=iOS",
            "-archivePath", archivePath.path,
            "CODE_SIGN_STYLE=Automatic",
            "-authenticationKeyIssuerID", issuerId,
            "-authenticationKeyID", keyId,
            "-authenticationKeyPath", keyPath.path,
            "-allowProvisioningUpdates"
        ]
        
        try await runProcess(archiveProcess)

        // 8. Export IPA
        print("🚀 Exporting IPA...")
        let exportProcess = Process()
        exportProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        exportProcess.arguments = [
            "-exportArchive",
            "-archivePath", archivePath.path,
            "-exportOptionsPlist", exportOptionsPath.path,
            "-exportPath", buildDir.path,
            "-authenticationKeyIssuerID", issuerId,
            "-authenticationKeyID", keyId,
            "-authenticationKeyPath", keyPath.path,
            "-allowProvisioningUpdates"
        ]
        
        try await runProcess(exportProcess)

        // 9. Cleanup
        print("🧹 Cleaning up temporary build artifacts...")
        try? FileManager.default.removeItem(at: archivePath)
        try? FileManager.default.removeItem(at: exportOptionsPath)
        try? FileManager.default.removeItem(at: keyPath)

        print("✅ Success! Build completed for version \(version).")
        print("📦 IPA location: \(buildDir.appendingPathComponent("\(appName).ipa").path)")
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
}

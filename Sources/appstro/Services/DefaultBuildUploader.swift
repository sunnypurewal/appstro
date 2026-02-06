import Foundation
import AppstroCore

public struct DefaultBuildUploader: BuildUploader {
    public init() {}

    public func uploadIPA(ipaURL: URL, issuerId: String, keyId: String, privateKey: String) async throws {
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
}

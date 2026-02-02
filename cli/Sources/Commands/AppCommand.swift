import ArgumentParser
import Foundation

struct App: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app",
        abstract: "Fetch details of an app from App Store Connect."
    )

    @Argument(help: "The name of the app or its bundle identifier.")
    var parameter: String

    func run() async throws {
        // 1. Interpret the parameter
        let interpreter = AppQueryInterpreter()
        let query = interpreter.interpret(parameter)
        
        // 2. Get credentials from environment
        guard let issuerId = ProcessInfo.processInfo.environment["APPSTORE_ISSUER_ID"],
              let keyId = ProcessInfo.processInfo.environment["APPSTORE_KEY_ID"],
              let privateKey = ProcessInfo.processInfo.environment["APPSTORE_PRIVATE_KEY"] else {
            print("❌ Error: Missing App Store Connect credentials in environment variables.")
            print("👉 Run 'appstro login' to find your credentials and see setup instructions.")
            return
        }
        
        // 3. Fetch details
        let service = try AppStoreConnectService(issuerId: issuerId, keyId: keyId, privateKey: privateKey)
        
        print("🔍 Searching for app: \(parameter)...")
        
        do {
            if let details = try await service.fetchAppDetails(query: query) {
                print("\n📱 App Details:")
                print("-------------------")
                print("Name:           \(details.name)")
                print("Bundle ID:      \(details.bundleId)")
                print("App Store URL:  \(details.appStoreUrl)")
                
                if let version = details.publishedVersion {
                    print("Status:         Published")
                    print("Active Version: \(version)")
                } else {
                    print("Status:         No published version exists")
                }
            } else {
                print("❌ No app found matching: \(parameter)")
            }
        } catch {
            print("❌ Error: \(error)")
        }
    }
}

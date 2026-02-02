import ArgumentParser
import Foundation

struct Login: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "login",
        abstract: "Open the App Store Connect page to manage API keys."
    )

    func run() throws {
        let urlString = "https://appstoreconnect.apple.com/access/integrations/api"
        
        print("🔐 App Store Connect API Setup")
        print("-------------------------------")
        print("Once the webpage opens, follow these steps:")
        print("1. Click the '+' button to add a new API Key.")
        print("2. IMPORTANT: Choose 'Admin' or 'App Manager' in the 'Access' dropdown.")
        print("   (Lower roles like 'Sales' cannot create apps).")
        print("3. Enter a name for the key and click 'Generate'.")
        print("4. Once created, copy the 'Key ID'.")
        print("4. Click 'Download API Key' to get the .p8 private key file.")
        print("5. Note your 'Issuer ID' found at the top of the page.")
        
        print("\nPress Enter to open the App Store Connect page in your browser...")
        _ = readLine()
        
        print("🌐 Opening...")
        print("🔗 \(urlString)")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [urlString]
        
        do {
            try process.run()
        } catch {
            print("❌ Failed to open browser. Please visit the URL manually.")
        }
        
        print("\n💡 After creating your key, set the following environment variables:")
        print("export APPSTORE_ISSUER_ID='your-issuer-id'")
        print("export APPSTORE_KEY_ID='your-key-id'")
        print("export APPSTORE_PRIVATE_KEY='$(cat /path/to/your/AuthKey.p8)'")
    }
}


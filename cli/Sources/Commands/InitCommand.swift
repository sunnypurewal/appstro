import ArgumentParser
import Foundation
import XcodeGenKit
import ProjectSpec
import PathKit
import XcodeProj

struct Init: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Initialize a new iOS project."
    )

    @Argument(help: "The name of the app to create.")
    var name: String

    func run() throws {
        let currentPath = Path.current
        let projectPath = currentPath + name
        let sourcesPath = projectPath + "Sources"

        print("🚀 Creating project '\(name)' at \(projectPath)...")

        // 1. Create directories
        try sourcesPath.mkpath()

        // 2. Create basic SwiftUI files
        let appSwift = """
        import SwiftUI

        @main
        struct \(name)App: App {
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
                    Text("Hello, \(name)!")
                }
                .padding()
            }
        }
        """

        try (sourcesPath + "App.swift").write(appSwift)
        try (sourcesPath + "ContentView.swift").write(contentViewSwift)

        // 3. Define Project using XcodeGen
        let buildSettings: [String: Any] = [
            "PRODUCT_BUNDLE_IDENTIFIER": "com.appstro.\(name)",
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
            name: name,
            type: .application,
            platform: .iOS,
            deploymentTarget: "16.0",
            settings: Settings(buildSettings: buildSettings),
            sources: [TargetSource(path: "Sources")]
        )

        let project = Project(
            basePath: projectPath,
            name: name,
            configs: [
                Config(name: "Debug", type: .debug),
                Config(name: "Release", type: .release)
            ],
            targets: [target],
            options: SpecOptions(xcodeVersion: "16.0")
        )

        // 4. Generate Xcode Project
        print("🛠 Generating Xcode project (Xcode 16 format)...")
        let generator = ProjectGenerator(project: project)
        let xcodeProject = try generator.generateXcodeProject(userName: NSFullUserName())
        
        // Manually set latest compatibility and object versions for Xcode 16
        xcodeProject.pbxproj.rootObject?.compatibilityVersion = "Xcode 16.0"
        xcodeProject.pbxproj.rootObject?.attributes["LastUpgradeCheck"] = "1600"
        xcodeProject.pbxproj.rootObject?.preferredProjectObjectVersion = 77
        
        let xcodeProjectPath = projectPath + "\(name).xcodeproj"
        try xcodeProject.write(path: xcodeProjectPath)

        print("✅ Success! Project generated at \(xcodeProjectPath)")
        print("👉 To open: open \(xcodeProjectPath)")
    }
}

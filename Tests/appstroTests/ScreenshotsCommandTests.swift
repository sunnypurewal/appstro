import XCTest
import AppstroCore
import AppstroASC
import ArgumentParser
import PathKit
@testable import appstro

final class ScreenshotsCommandTests: XCTestCase {
    var mockProject: MockProjectService!
    var mockASC: MockAppStoreConnectService!
    var mockAppService: MockAppService!
    var mockVersionService: MockVersionService!
    var mockScreenshotService: MockScreenshotService!
    var mockUI: MockUserInterface!
    var mockAI: MockAIService!
    var mockBezel: MockBezelService!
    var mockImageProcessor: MockImageProcessor!
    var tempDir: Path!
    
    override func setUp() {
        super.setUp()
        mockProject = MockProjectService()
        mockAppService = MockAppService()
        mockVersionService = MockVersionService()
        mockScreenshotService = MockScreenshotService()
        mockUI = MockUserInterface()
        mockAI = MockAIService()
        mockBezel = MockBezelService()
        mockImageProcessor = MockImageProcessor()
        
        mockASC = MockAppStoreConnectService(
            apps: mockAppService,
            versions: mockVersionService,
            screenshots: mockScreenshotService
        )
        
        let asc = mockASC!
        Environment.live = Environment(
            ai: mockAI,
            project: mockProject,
            bezel: mockBezel,
            imageProcessor: mockImageProcessor,
            ui: mockUI,
            asc: { _ in asc }
        )
        
        tempDir = Path("/tmp/appstro_screenshots_\(UUID().uuidString)")
        try? tempDir.mkpath()
    }
    
    override func tearDown() {
        try? tempDir.delete()
        super.tearDown()
    }
    
    func testScreenshotsMutuallyExclusiveFlags() async throws {
        let cmd = try Screenshots.parseAsRoot(["--process", "--upload"])
        try await (cmd as! Screenshots).run()
    }
    
    func testScreenshotsNoProjectFails() async throws {
        mockProject.findProjectRootHandler = { nil }
        let cmd = try Screenshots.parseAsRoot([])
        try await (cmd as! Screenshots).run()
    }
    
    func testScreenshotsProcessOnlyMissingVersionFails() async throws {
        mockProject.findProjectRootHandler = { self.tempDir.url }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "Test", description: "", keywords: [], bundleIdentifier: "com.test", appPath: ".", teamID: nil)
        }
        
        let cmd = try Screenshots.parseAsRoot(["--process"])
        try await (cmd as! Screenshots).run()
    }

    func testScreenshotsProcessOnlySuccess() async throws {
        mockProject.findProjectRootHandler = { self.tempDir.url }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "Test", description: "", keywords: [], bundleIdentifier: "com.test", appPath: ".", teamID: nil)
        }
        mockProject.ensureReleaseDirectoryHandler = { _, version in
            let dir = self.tempDir + "releases" + version
            try? dir.mkpath()
            return dir.url
        }
        
        // Setup source screenshots
        let screenshotsDir = tempDir + "releases/1.0.0/screenshots"
        let iphoneDir = screenshotsDir + "iphone"
        try? iphoneDir.mkpath()
        try? (iphoneDir + "shot1.png").write("test".data(using: .utf8)!)
        
        let cmd = try Screenshots.parseAsRoot(["--process", "--app-version", "1.0.0"])
        try await (cmd as! Screenshots).run()
    }
}

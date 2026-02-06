import XCTest
import AppstroCore
import AppstroASC
import ArgumentParser
@testable import appstro

final class ContentRightsCommandTests: XCTestCase {
    var mockProject: MockProjectService!
    var mockASC: MockAppStoreConnectService!
    var mockAppService: MockAppService!
    var mockVersionService: MockVersionService!
    var mockUI: MockUserInterface!
    var mockAI: MockAIService!
    
    override func setUp() {
        super.setUp()
        mockProject = MockProjectService()
        mockAppService = MockAppService()
        mockVersionService = MockVersionService()
        mockUI = MockUserInterface()
        mockAI = MockAIService()
        
        mockASC = MockAppStoreConnectService(
            apps: mockAppService,
            versions: mockVersionService
        )
        
        let asc = mockASC!
        Environment.live = Environment(
            ai: mockAI,
            project: mockProject,
            ui: mockUI,
            asc: { _ in asc }
        )
    }
    
    func testContentRightsSuccess() async throws {
        mockProject.findProjectRootHandler = { URL(fileURLWithPath: "/test") }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "TestApp", description: "Desc", keywords: [], bundleIdentifier: "com.test", appPath: ".", teamID: nil)
        }
        mockAppService.listAppsHandler = {
            [AppInfo(id: "app1", name: "TestApp", bundleId: "com.test")]
        }
        mockVersionService.findDraftVersionHandler = { _ in
            DraftVersion(version: "1.0.0", id: "v1", state: .prepareForSubmission)
        }
        
        mockAI.analyzeContentRightsHandler = { _, _ in
            ContentRightsAnalysis(usesThirdPartyContent: false, reasoning: "Test reasoning")
        }
        
        mockUI.promptHandler = { text, defaultValue in
            return defaultValue ?? "n"
        }
        
        let cmd = try ContentRights.parseAsRoot(["--yes"])
        try await (cmd as! ContentRights).run()
    }
}

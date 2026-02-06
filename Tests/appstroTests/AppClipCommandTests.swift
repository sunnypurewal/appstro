import XCTest
import AppstroCore
import AppstroASC
import ArgumentParser
@testable import appstro

final class AppClipCommandTests: XCTestCase {
    var mockProject: MockProjectService!
    var mockASC: MockAppStoreConnectService!
    var mockAppService: MockAppService!
    var mockVersionService: MockVersionService!
    var mockAppClipService: MockAppClipService!
    var mockUI: MockUserInterface!
    
    override func setUp() {
        super.setUp()
        mockProject = MockProjectService()
        mockAppService = MockAppService()
        mockVersionService = MockVersionService()
        mockAppClipService = MockAppClipService()
        mockUI = MockUserInterface()
        
        mockASC = MockAppStoreConnectService(
            apps: mockAppService,
            versions: mockVersionService,
            appClips: mockAppClipService
        )
        
        let asc = mockASC!
        Environment.live = Environment(
            project: mockProject,
            ui: mockUI,
            asc: { _ in asc }
        )
    }
    
    func testDeleteDefaultAppClipById() async throws {
        let cmd = try DeleteAppClip.parseAsRoot(["id123"])
        try await (cmd as! DeleteAppClip).run()
    }
    
    func testDeleteAdvancedAppClipById() async throws {
        let cmd = try DeleteAppClip.parseAsRoot(["id456", "--advanced"])
        try await (cmd as! DeleteAppClip).run()
    }
    
    func testDeleteDefaultAppClipAutoFetch() async throws {
        mockProject.findProjectRootHandler = { URL(fileURLWithPath: "/test") }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "Test", description: "", keywords: [], bundleIdentifier: "com.test", appPath: ".", teamID: nil)
        }
        mockAppService.fetchAppDetailsHandler = { _ in
            AppDetails(id: "app1", name: "Test", bundleId: "com.test", appStoreUrl: "", publishedVersion: nil)
        }
        mockVersionService.findDraftVersionHandler = { _ in
            DraftVersion(version: "1.0.0", id: "v1", state: .prepareForSubmission)
        }
        
        let cmd = try DeleteAppClip.parseAsRoot([])
        try await (cmd as! DeleteAppClip).run()
    }
}

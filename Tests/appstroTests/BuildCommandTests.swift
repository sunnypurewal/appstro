import XCTest
import AppstroCore
import AppstroASC
import ArgumentParser
@testable import appstro

final class BuildCommandTests: XCTestCase {
    var mockProject: MockProjectService!
    var mockASC: MockAppStoreConnectService!
    var mockAppService: MockAppService!
    var mockVersionService: MockVersionService!
    
    override func setUp() {
        super.setUp()
        mockProject = MockProjectService()
        mockAppService = MockAppService()
        mockVersionService = MockVersionService()
        mockASC = MockAppStoreConnectService(apps: mockAppService, versions: mockVersionService)
        
        let asc = mockASC!
        Environment.live = Environment(
            project: mockProject,
            asc: { _ in asc }
        )
    }
    
    func testBuildSuccess() async throws {
        let root = URL(fileURLWithPath: "/test")
        mockProject.findProjectRootHandler = { root }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "TestApp", description: "Desc", keywords: [], bundleIdentifier: "com.test.app", appPath: ".", teamID: "ABC") 
        }
        
        mockAppService.fetchAppDetailsHandler = { _ in
            AppDetails(id: "app123", name: "TestApp", bundleId: "com.test.app", appStoreUrl: "http://test.com", publishedVersion: nil)
        }
        
        mockVersionService.fetchBuildsHandler = { _, _ in
            [BuildInfo(id: "b1", version: "10", processingState: .valid)]
        }
        
        mockVersionService.findDraftVersionHandler = { _ in
            DraftVersion(version: "1.0.0", id: "v1", state: .prepareForSubmission)
        }
        
        mockProject.buildHandler = { _, _, _, _ in
            URL(fileURLWithPath: "/test/build.ipa")
        }
        
        let cmd = Build()
        try await cmd.run()
    }
    
    func testBuildNoProjectFails() async throws {
        mockProject.findProjectRootHandler = { nil }
        
        let cmd = Build()
        try await cmd.run()
    }
    
    func testBuildAutoDetectTeamID() async throws {
        let root = URL(fileURLWithPath: "/test")
        mockProject.findProjectRootHandler = { root }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "TestApp", description: "Desc", keywords: [], bundleIdentifier: "com.test.app", appPath: ".", teamID: nil) 
        }
        
        mockProject.getTeamIDHandler = { _ in "AUTO_TEAM_ID" }
        
        mockAppService.fetchAppDetailsHandler = { _ in
            AppDetails(id: "app123", name: "TestApp", bundleId: "com.test.app", appStoreUrl: "http://test.com", publishedVersion: nil)
        }
        
        mockVersionService.fetchBuildsHandler = { _, _ in [] }
        
        mockVersionService.findDraftVersionHandler = { _ in
            DraftVersion(version: "1.0.0", id: "v1", state: .prepareForSubmission)
        }
        
        mockProject.buildHandler = { _, _, _, _ in
            URL(fileURLWithPath: "/test/build.ipa")
        }
        
        let cmd = Build()
        try await cmd.run()
    }
}

import XCTest
import AppstroCore
import AppstroASC
import ArgumentParser
@testable import appstro

final class PrivacyCommandTests: XCTestCase {
    var mockProject: MockProjectService!
    var mockASC: MockAppStoreConnectService!
    var mockAppService: MockAppService!
    var mockMetadataService: MockMetadataService!
    var mockUI: MockUserInterface!
    
    override func setUp() {
        super.setUp()
        mockProject = MockProjectService()
        mockAppService = MockAppService()
        mockMetadataService = MockMetadataService()
        mockUI = MockUserInterface()
        
        mockASC = MockAppStoreConnectService(
            apps: mockAppService,
            metadata: mockMetadataService
        )
        
        let asc = mockASC!
        Environment.live = Environment(
            project: mockProject,
            ui: mockUI,
            asc: { _ in asc }
        )
    }
    
    func testPrivacyUpdateWithUrl() async throws {
        mockProject.findProjectRootHandler = { URL(fileURLWithPath: "/test") }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "Test", description: "", keywords: [], bundleIdentifier: "com.test", appPath: ".", teamID: nil)
        }
        mockAppService.fetchAppDetailsHandler = { _ in
            AppDetails(id: "app1", name: "Test", bundleId: "com.test", appStoreUrl: "", publishedVersion: nil)
        }
        
        let cmd = try Privacy.parseAsRoot(["--url", "https://test.com/privacy"])
        try await (cmd as! Privacy).run()
    }
}

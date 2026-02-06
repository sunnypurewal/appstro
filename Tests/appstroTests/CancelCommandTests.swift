import XCTest
import AppstroCore
import AppstroASC
import ArgumentParser
@testable import appstro

final class CancelCommandTests: XCTestCase {
    var mockProject: MockProjectService!
    var mockASC: MockAppStoreConnectService!
    var mockAppService: MockAppService!
    var mockReviewService: MockReviewService!
    var mockUI: MockUserInterface!
    
    override func setUp() {
        super.setUp()
        mockProject = MockProjectService()
        mockAppService = MockAppService()
        mockReviewService = MockReviewService()
        mockUI = MockUserInterface()
        
        mockASC = MockAppStoreConnectService(
            apps: mockAppService,
            reviews: mockReviewService
        )
        
        let asc = mockASC!
        Environment.live = Environment(
            project: mockProject,
            ui: mockUI,
            asc: { _ in asc }
        )
    }
    
    func testCancelSuccess() async throws {
        mockProject.findProjectRootHandler = { URL(fileURLWithPath: "/test") }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "Test", description: "", keywords: [], bundleIdentifier: "com.test", appPath: ".", teamID: nil)
        }
        mockAppService.fetchAppDetailsHandler = { _ in
            AppDetails(id: "app1", name: "Test", bundleId: "com.test", appStoreUrl: "", publishedVersion: nil)
        }
        
        let cmd = try Cancel.parseAsRoot([])
        try await (cmd as! Cancel).run()
    }
}

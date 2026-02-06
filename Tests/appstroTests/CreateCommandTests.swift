import XCTest
import AppstroCore
import AppstroASC
import ArgumentParser
@testable import appstro

final class CreateCommandTests: XCTestCase {
    var mockProject: MockProjectService!
    var mockASC: MockAppStoreConnectService!
    var mockBundleIdService: MockBundleIdService!
    var mockUI: MockUserInterface!
    
    override func setUp() {
        super.setUp()
        mockProject = MockProjectService()
        mockBundleIdService = MockBundleIdService()
        mockUI = MockUserInterface()
        
        mockASC = MockAppStoreConnectService(
            bundleIds: mockBundleIdService
        )
        
        let asc = mockASC!
        Environment.live = Environment(
            project: mockProject,
            ui: mockUI,
            asc: { _ in asc }
        )
    }
    
    func testCreateAppSuccess() async throws {
        mockBundleIdService.deduceBundleIdPrefixHandler = { _ in "com.test" }
        
        let cmd = try Create.parseAsRoot(["TestApp"])
        try await (cmd as! Create).run()
    }
}

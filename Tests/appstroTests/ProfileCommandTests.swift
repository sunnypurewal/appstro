import XCTest
import AppstroCore
import AppstroASC
import ArgumentParser
import PathKit
@testable import appstro

final class ProfileCommandTests: XCTestCase {
    var mockProject: MockProjectService!
    var mockASC: MockAppStoreConnectService!
    var mockAppService: MockAppService!
    var mockCertificateService: MockCertificateService!
    var mockBundleIdService: MockBundleIdService!
    var mockAI: MockAIService!
    var mockUI: MockUserInterface!
    var tempDir: Path!
    
    override func setUp() {
        super.setUp()
        mockProject = MockProjectService()
        mockAppService = MockAppService()
        mockCertificateService = MockCertificateService()
        mockBundleIdService = MockBundleIdService()
        mockAI = MockAIService()
        mockUI = MockUserInterface()
        
        mockASC = MockAppStoreConnectService(
            apps: mockAppService,
            certificates: mockCertificateService,
            bundleIds: mockBundleIdService
        )
        
        let asc = mockASC!
        Environment.live = Environment(
            ai: mockAI,
            project: mockProject,
            ui: mockUI,
            asc: { _ in asc }
        )
        
        tempDir = Path("/tmp/appstro_profile_\(UUID().uuidString)")
        try? tempDir.mkpath()
    }
    
    override func tearDown() {
        try? tempDir.delete()
        super.tearDown()
    }
    
    func testCreateProfileSuccess() async throws {
        mockProject.findProjectRootHandler = { self.tempDir.url }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "TestApp", description: "", keywords: [], bundleIdentifier: "com.test", appPath: ".", teamID: nil)
        }
        
        mockAppService.listAppsHandler = {
            [AppInfo(id: "app1", name: "TestApp", bundleId: "com.test")]
        }
        
        let cmd = try CreateProfile.parseAsRoot([])
        try await (cmd as! CreateProfile).run()
    }
}
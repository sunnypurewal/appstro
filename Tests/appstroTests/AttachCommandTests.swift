import XCTest
import AppstroCore
import AppstroASC
import ArgumentParser
import PathKit
@testable import appstro

final class AttachCommandTests: XCTestCase {
    var mockProject: MockProjectService!
    var mockASC: MockAppStoreConnectService!
    var mockAppService: MockAppService!
    var mockVersionService: MockVersionService!
    var mockReviewService: MockReviewService!
    var mockUI: MockUserInterface!
    var tempDir: Path!
    
    override func setUp() {
        super.setUp()
        mockProject = MockProjectService()
        mockAppService = MockAppService()
        mockVersionService = MockVersionService()
        mockReviewService = MockReviewService()
        mockUI = MockUserInterface()
        
        mockASC = MockAppStoreConnectService(
            apps: mockAppService,
            versions: mockVersionService,
            reviews: mockReviewService
        )
        
        let asc = mockASC!
        Environment.live = Environment(
            project: mockProject,
            ui: mockUI,
            asc: { _ in asc }
        )
        
        tempDir = Path("/tmp/appstro_attach_\(UUID().uuidString)")
        try? tempDir.mkpath()
    }
    
    override func tearDown() {
        try? tempDir.delete()
        super.tearDown()
    }
    
    func testAttachSuccess() async throws {
        let file = tempDir + "doc.pdf"
        try? file.write("data".data(using: .utf8)!)
        
        mockProject.findProjectRootHandler = { self.tempDir.url }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "Test", description: "", keywords: [], bundleIdentifier: "com.test", appPath: ".", teamID: nil)
        }
        mockAppService.fetchAppDetailsHandler = { _ in
            AppDetails(id: "app1", name: "Test", bundleId: "com.test", appStoreUrl: "", publishedVersion: nil)
        }
        mockVersionService.findDraftVersionHandler = { _ in
            DraftVersion(version: "1.0.0", id: "v1", state: .prepareForSubmission)
        }
        
        let cmd = try Attach.parseAsRoot([file.string])
        try await (cmd as! Attach).run()
    }
}

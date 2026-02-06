import XCTest
import AppstroCore
import AppstroASC
import ArgumentParser
import PathKit
@testable import appstro

final class UploadCommandTests: XCTestCase {
    var mockProject: MockProjectService!
    var mockASC: MockAppStoreConnectService!
    var mockAppService: MockAppService!
    var mockVersionService: MockVersionService!
    var mockUploader: MockBuildUploader!
    var mockUI: MockUserInterface!
    var tempDir: Path!
    
    override func setUp() {
        super.setUp()
        mockProject = MockProjectService()
        mockAppService = MockAppService()
        mockVersionService = MockVersionService()
        mockUploader = MockBuildUploader()
        mockUI = MockUserInterface()
        
        mockASC = MockAppStoreConnectService(
            apps: mockAppService,
            versions: mockVersionService
        )
        
        let asc = mockASC!
        Environment.live = Environment(
            project: mockProject,
            ui: mockUI,
            uploader: mockUploader,
            asc: { _ in asc }
        )
        
        tempDir = Path("/tmp/appstro_upload_\(UUID().uuidString)")
        try? tempDir.mkpath()
    }
    
    override func tearDown() {
        try? tempDir.delete()
        super.tearDown()
    }
    
    func testUploadSuccess() async throws {
        // Setup credentials in environment
        setenv("APPSTORE_ISSUER_ID", "issuer", 1)
        setenv("APPSTORE_KEY_ID", "key", 1)
        setenv("APPSTORE_PRIVATE_KEY", "private", 1)
        
        let ipa = tempDir + "test.ipa"
        try? ipa.write("ipa data".data(using: .utf8)!)
        
        mockAppService.listAppsHandler = {
            [AppInfo(id: "app1", name: "TestApp", bundleId: "com.test")]
        }
        mockVersionService.findDraftVersionHandler = { _ in
            DraftVersion(version: "1.0.0", id: "v1", state: .prepareForSubmission)
        }
        
        // Mock fetchBuilds for wait loop
        var fetchCount = 0
        mockVersionService.fetchBuildsHandler = { _, _ in
            fetchCount += 1
            if fetchCount == 1 {
                return [] // Before upload
            } else {
                return [BuildInfo(id: "b1", version: "1.0.0 (1)", processingState: .valid)] // After upload
            }
        }
        
        let cmd = try Upload.parseAsRoot([ipa.string])
        try await (cmd as! Upload).run()
    }
}

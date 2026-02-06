import XCTest
import AppstroCore
import AppstroASC
import ArgumentParser
@testable import appstro

final class AppCommandTests: XCTestCase {
    var mockASC: MockAppStoreConnectService!
    var mockAppService: MockAppService!
    
    override func setUp() {
        super.setUp()
        mockAppService = MockAppService()
        mockASC = MockAppStoreConnectService(apps: mockAppService)
        
        let asc = mockASC!
        Environment.live = Environment(
            asc: { _ in asc }
        )
    }
    
    func testAppCommandSuccess() async throws {
        mockAppService.fetchAppDetailsHandler = { query in
            AppDetails(id: "app1", name: "TestApp", bundleId: "com.test", appStoreUrl: "https://apple.com", publishedVersion: "1.0.0")
        }
        
        var cmd = App()
        cmd.parameter = "TestApp"
        try await cmd.run()
    }
    
    func testAppCommandNoPublishedVersion() async throws {
        mockAppService.fetchAppDetailsHandler = { query in
            AppDetails(id: "app1", name: "TestApp", bundleId: "com.test", appStoreUrl: "https://apple.com", publishedVersion: nil)
        }
        
        var cmd = App()
        cmd.parameter = "TestApp"
        try await cmd.run()
    }
}

import XCTest
import AppstroCore
import AppstroASC
import ArgumentParser
@testable import appstro

final class PricingCommandTests: XCTestCase {
    var mockProject: MockProjectService!
    var mockASC: MockAppStoreConnectService!
    var mockAppService: MockAppService!
    var mockPricingService: MockPricingService!
    var mockUI: MockUserInterface!
    
    override func setUp() {
        super.setUp()
        mockProject = MockProjectService()
        mockAppService = MockAppService()
        mockPricingService = MockPricingService()
        mockUI = MockUserInterface()
        
        mockASC = MockAppStoreConnectService(
            apps: mockAppService,
            pricing: mockPricingService
        )
        
        let asc = mockASC!
        Environment.live = Environment(
            project: mockProject,
            ui: mockUI,
            asc: { _ in asc }
        )
    }
    
    func testPricingList() async throws {
        mockProject.findProjectRootHandler = { URL(fileURLWithPath: "/test") }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "Test", description: "", keywords: [], bundleIdentifier: "com.test", appPath: ".", teamID: nil)
        }
        mockAppService.fetchAppDetailsHandler = { _ in
            AppDetails(id: "app1", name: "Test", bundleId: "com.test", appStoreUrl: "", publishedVersion: nil)
        }
        
        let cmd = try Pricing.parseAsRoot(["--list"])
        try await (cmd as! Pricing).run()
    }
    
    func testPricingUpdate() async throws {
        mockProject.findProjectRootHandler = { URL(fileURLWithPath: "/test") }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "Test", description: "", keywords: [], bundleIdentifier: "com.test", appPath: ".", teamID: nil)
        }
        mockAppService.fetchAppDetailsHandler = { _ in
            AppDetails(id: "app1", name: "Test", bundleId: "com.test", appStoreUrl: "", publishedVersion: nil)
        }
        
        let cmd = try Pricing.parseAsRoot(["--price", "0.99"])
        try await (cmd as! Pricing).run()
    }
}

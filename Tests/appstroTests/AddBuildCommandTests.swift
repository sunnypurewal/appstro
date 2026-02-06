import XCTest
import AppstroCore
import AppstroASC
import ArgumentParser
@testable import appstro

final class AddBuildCommandTests: XCTestCase {
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
    
    func testAddBuildSuccess() async throws {
        let root = URL(fileURLWithPath: "/test")
        mockProject.findProjectRootHandler = { root }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "TestApp", description: "Desc", keywords: [], bundleIdentifier: "com.test.app", appPath: ".", teamID: "ABC") 
        }
        
        mockAppService.fetchAppDetailsHandler = { _ in
            AppDetails(id: "app123", name: "TestApp", bundleId: "com.test.app", appStoreUrl: "http://test.com", publishedVersion: nil)
        }
        
        mockVersionService.findDraftVersionHandler = { appId in
            DraftVersion(version: "1.0.0", id: "ver123", state: .prepareForSubmission)
        }
        
        mockVersionService.fetchBuildsHandler = { appId, version in
            [
                BuildInfo(id: "build1", version: "1.0.0 (1)", processingState: .valid),
                BuildInfo(id: "build2", version: "1.0.0 (2)", processingState: .processing)
            ]
        }
        
        var attached = false
        mockVersionService.attachBuildToVersionHandler = { versionId, buildId in
            attached = true
        }
        
        let cmd = AddBuild()
        try await cmd.run()
        
        XCTAssertTrue(attached)
    }

    func testAddBuildNoProjectFails() async throws {
        mockProject.findProjectRootHandler = { nil }
        
        let cmd = AddBuild()
        try await cmd.run()
        // Should log error but not crash
    }

    func testAddBuildAppNotFound() async throws {
        let root = URL(fileURLWithPath: "/test")
        mockProject.findProjectRootHandler = { root }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "TestApp", description: "Desc", keywords: [], bundleIdentifier: "com.test.app", appPath: ".", teamID: "ABC") 
        }
        
        mockAppService.fetchAppDetailsHandler = { _ in nil }
        
        let cmd = AddBuild()
        try await cmd.run()
    }

    func testAddBuildNoDraftVersion() async throws {
        let root = URL(fileURLWithPath: "/test")
        mockProject.findProjectRootHandler = { root }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "TestApp", description: "Desc", keywords: [], bundleIdentifier: "com.test.app", appPath: ".", teamID: "ABC") 
        }
        
        mockAppService.fetchAppDetailsHandler = { _ in
            AppDetails(id: "app123", name: "TestApp", bundleId: "com.test.app", appStoreUrl: "http://test.com", publishedVersion: nil)
        }
        
        mockVersionService.findDraftVersionHandler = { _ in nil }
        
        let cmd = AddBuild()
        try await cmd.run()
    }

    func testAddBuildNoValidBuilds() async throws {
        let root = URL(fileURLWithPath: "/test")
        mockProject.findProjectRootHandler = { root }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "TestApp", description: "Desc", keywords: [], bundleIdentifier: "com.test.app", appPath: ".", teamID: "ABC") 
        }
        
        mockAppService.fetchAppDetailsHandler = { _ in
            AppDetails(id: "app123", name: "TestApp", bundleId: "com.test.app", appStoreUrl: "http://test.com", publishedVersion: nil)
        }
        
        mockVersionService.findDraftVersionHandler = { _ in
            DraftVersion(version: "1.0.0", id: "ver123", state: .prepareForSubmission)
        }
        
        mockVersionService.fetchBuildsHandler = { _, _ in
            [BuildInfo(id: "build2", version: "1.0.0 (2)", processingState: .processing)]
        }
        
        let cmd = AddBuild()
        try await cmd.run()
    }
}

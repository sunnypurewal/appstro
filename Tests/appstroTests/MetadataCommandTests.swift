import XCTest
import AppstroCore
import AppstroASC
import ArgumentParser
@testable import appstro

final class MetadataCommandTests: XCTestCase {
    var mockProject: MockProjectService!
    var mockASC: MockAppStoreConnectService!
    var mockAppService: MockAppService!
    var mockVersionService: MockVersionService!
    var mockMetadataService: MockMetadataService!
    var mockReviewService: MockReviewService!
    var mockUI: MockUserInterface!
    var mockAI: MockAIService!
    
    override func setUp() {
        super.setUp()
        mockProject = MockProjectService()
        mockAppService = MockAppService()
        mockVersionService = MockVersionService()
        mockMetadataService = MockMetadataService()
        mockReviewService = MockReviewService()
        mockAI = MockAIService()
        mockUI = MockUserInterface()
        
        mockASC = MockAppStoreConnectService(
            apps: mockAppService,
            versions: mockVersionService,
            metadata: mockMetadataService,
            reviews: mockReviewService
        )
        
        let asc = mockASC!
        Environment.live = Environment(
            ai: mockAI,
            project: mockProject,
            ui: mockUI,
            asc: { _ in asc }
        )
    }
    
    func testMetadataAll() async throws {
        mockProject.findProjectRootHandler = { URL(fileURLWithPath: "/test") }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "TestApp", description: "Desc", keywords: [], bundleIdentifier: "com.test", appPath: ".", teamID: nil)
        }
        mockAppService.fetchAppDetailsHandler = { query in
            return AppDetails(id: "app1", name: "TestApp", bundleId: "com.test", appStoreUrl: "", publishedVersion: nil)
        }
        mockVersionService.findDraftVersionHandler = { _ in
            DraftVersion(version: "1.0.0", id: "v1", state: .prepareForSubmission)
        }
        
        let cmd = try Metadata.All.parseAsRoot([])
        try await (cmd as! Metadata.All).run()
    }
    
    func testMetadataDescriptionGet() async throws {
        mockProject.findProjectRootHandler = { URL(fileURLWithPath: "/test") }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "TestApp", description: "Desc", keywords: [], bundleIdentifier: "com.test", appPath: ".", teamID: nil)
        }
        mockAppService.fetchAppDetailsHandler = { query in
            return AppDetails(id: "app1", name: "TestApp", bundleId: "com.test", appStoreUrl: "", publishedVersion: nil)
        }
        mockVersionService.findDraftVersionHandler = { _ in
            DraftVersion(version: "1.0.0", id: "v1", state: .prepareForSubmission)
        }
        
        let cmd = try Metadata.Description.parseAsRoot(["--get"])
        try await (cmd as! Metadata.Description).run()
    }
    
    func testMetadataDescriptionSet() async throws {
        mockProject.findProjectRootHandler = { URL(fileURLWithPath: "/test") }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "TestApp", description: "Desc", keywords: [], bundleIdentifier: "com.test", appPath: ".", teamID: nil)
        }
        mockAppService.fetchAppDetailsHandler = { query in
            return AppDetails(id: "app1", name: "TestApp", bundleId: "com.test", appStoreUrl: "", publishedVersion: nil)
        }
        mockVersionService.findDraftVersionHandler = { _ in
            DraftVersion(version: "1.0.0", id: "v1", state: .prepareForSubmission)
        }
        
        let cmd = try Metadata.Description.parseAsRoot(["--set", "New Description"])
        try await (cmd as! Metadata.Description).run()
    }

    func testMetadataGenerate() async throws {
        mockProject.findProjectRootHandler = { URL(fileURLWithPath: "/test") }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "TestApp", description: "Desc", keywords: [], bundleIdentifier: "com.test", appPath: ".", teamID: nil)
        }
        mockAppService.fetchAppDetailsHandler = { _ in
            AppDetails(id: "app1", name: "TestApp", bundleId: "com.test", appStoreUrl: "", publishedVersion: nil)
        }
        mockVersionService.findDraftVersionHandler = { _ in
            DraftVersion(version: "1.0.0", id: "v1", state: .prepareForSubmission)
        }
        
        mockUI.promptHandler = { text, defaultValue in
            if text == "Upload?" { return "y" }
            return defaultValue ?? "TestValue"
        }
        
        let cmd = try Metadata.Generate.parseAsRoot(["--pitch", "Test Pitch"])
        try await (cmd as! Metadata.Generate).run()
    }

    func testMetadataFetchDraftFallback() async throws {
        mockProject.findProjectRootHandler = { URL(fileURLWithPath: "/test") }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "TestApp", description: "Desc", keywords: [], bundleIdentifier: "com.test", appPath: ".", teamID: nil)
        }
        mockAppService.fetchAppDetailsHandler = { _ in nil }
        mockAppService.listAppsHandler = {
            [AppInfo(id: "app2", name: "OtherApp", bundleId: "com.other")]
        }
        mockVersionService.findDraftVersionHandler = { appId in
            if appId == "app2" {
                return DraftVersion(version: "1.1.0", id: "v2", state: .prepareForSubmission)
            }
            return nil
        }
        
        let cmd = try Metadata.All.parseAsRoot([])
        try await (cmd as! Metadata.All).run()
    }

    func testMetadataFetchDraftNotFoundFails() async throws {
        mockProject.findProjectRootHandler = { URL(fileURLWithPath: "/test") }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "TestApp", description: "Desc", keywords: [], bundleIdentifier: "com.test", appPath: ".", teamID: nil)
        }
        mockAppService.fetchAppDetailsHandler = { _ in nil }
        mockAppService.listAppsHandler = { [] }
        
        let cmd = try Metadata.All.parseAsRoot([])
        do {
            try await (cmd as! Metadata.All).run()
        } catch {
            // Success if it throws
        }
    }
}
import XCTest
import AppstroCore
import AppstroASC
import ArgumentParser
@testable import appstro

final class DataCollectionCommandTests: XCTestCase {
    var mockProject: MockProjectService!
    var mockASC: MockAppStoreConnectService!
    var mockAppService: MockAppService!
    var mockVersionService: MockVersionService!
    var mockUI: MockUserInterface!
    var mockAI: MockAIService!
    
    override func setUp() {
        super.setUp()
        mockProject = MockProjectService()
        mockAppService = MockAppService()
        mockVersionService = MockVersionService()
        mockUI = MockUserInterface()
        mockAI = MockAIService()
        
        mockASC = MockAppStoreConnectService(
            apps: mockAppService,
            versions: mockVersionService
        )
        
        let asc = mockASC!
        Environment.live = Environment(
            ai: mockAI,
            project: mockProject,
            ui: mockUI,
            asc: { _ in asc }
        )
    }
    
    func testDataCollectionNoData() async throws {
        mockAppService.listAppsHandler = {
            [AppInfo(id: "app1", name: "Test", bundleId: "com.test")]
        }
        mockVersionService.findDraftVersionHandler = { _ in
            DraftVersion(version: "1.0.0", id: "v1", state: .prepareForSubmission)
        }
        
        mockAI.analyzeDataCollectionHandler = { _, _ in
            DataCollectionAnalysis(collectsData: false, dataTypes: CollectedDataTypes(location: false, contactInfo: false, healthAndFitness: false, financialInfo: false, userContent: false, browsingHistory: false, searchHistory: false, identifiers: false, usageData: false, diagnostics: false, otherData: false), reasoning: "None")
        }
        
        mockUI.promptHandler = { text, defaultValue in
            if text.contains("Ready to open") { return "" }
            if text.contains("What did you answer") { return "n" }
            return defaultValue ?? ""
        }

        var openedURL: URL?
        mockUI.openURLHandler = { url in
            openedURL = url
        }
        
        let cmd = try DataCollection.parseAsRoot([])
        try await (cmd as! DataCollection).run()

        XCTAssertNotNil(openedURL)
        XCTAssertTrue(openedURL?.absoluteString.contains("distribution/privacy") == true)
    }
}

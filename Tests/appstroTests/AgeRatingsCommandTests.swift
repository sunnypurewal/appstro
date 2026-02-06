import XCTest
import AppstroCore
import AppstroASC
import ArgumentParser
@testable import appstro

final class AgeRatingsCommandTests: XCTestCase {
    var mockProject: MockProjectService!
    var mockASC: MockAppStoreConnectService!
    var mockAppService: MockAppService!
    var mockVersionService: MockVersionService!
    var mockAgeRatingService: MockAgeRatingService!
    var mockUI: MockUserInterface!
    var mockAI: MockAIService!
    
    override func setUp() {
        super.setUp()
        mockProject = MockProjectService()
        mockAppService = MockAppService()
        mockVersionService = MockVersionService()
        mockAgeRatingService = MockAgeRatingService()
        mockUI = MockUserInterface()
        mockAI = MockAIService()
        
        mockASC = MockAppStoreConnectService(
            apps: mockAppService,
            versions: mockVersionService,
            ageRatings: mockAgeRatingService
        )
        
        let asc = mockASC!
        Environment.live = Environment(
            ai: mockAI,
            project: mockProject,
            ui: mockUI,
            asc: { _ in asc }
        )
    }
    
    func testAgeRatingsSuccess() async throws {
        mockProject.findProjectRootHandler = { URL(fileURLWithPath: "/test") }
        mockProject.loadConfigHandler = { _ in 
            AppstroConfig(name: "TestApp", description: "Desc", keywords: [], bundleIdentifier: "com.test", appPath: ".", teamID: nil)
        }
        mockAppService.listAppsHandler = {
            [AppInfo(id: "app1", name: "TestApp", bundleId: "com.test")]
        }
        mockVersionService.findDraftVersionHandler = { _ in
            DraftVersion(version: "1.0.0", id: "v1", state: .prepareForSubmission)
        }
        
        mockAI.suggestAgeRatingsHandler = { _, _, _ in
            SuggestedAgeRatings(
                alcoholTobaccoOrDrugUseOrReference: "NONE",
                gamblingAndContests: false,
                gamblingSimulated: "NONE",
                horrorOrFearThemes: "NONE",
                matureOrSuggestiveThemes: "NONE",
                medicalOrTreatmentInformation: "NONE",
                profanityOrCrudeHumor: "NONE",
                sexualContentOrNudity: "NONE",
                sexualContentGraphicOrNudity: "NONE",
                violenceCartoonOrFantasy: "NONE",
                violenceRealistic: "NONE",
                violenceRealisticProlongedGraphicOrSadistic: "NONE",
                gunsOrOtherWeapons: "NONE",
                parentalControls: false,
                userGeneratedContent: false,
                ageAssurance: false,
                advertising: false,
                healthOrWellnessTopics: false,
                messagingAndChat: "NONE",
                unrestrictedWebAccess: false,
                kids17Plus: false,
                isLootBox: false,
                kidsAgeBand: nil,
                koreaAgeRatingOverride: "NONE",
                reasoning: "Test reasoning"
            )
        }
        
        mockUI.promptHandler = { text, defaultValue in
            if text == "Do you want to apply these ratings?" { return "y" }
            return defaultValue ?? ""
        }
        
        let cmd = try AgeRatings.parseAsRoot([])
        try await (cmd as! AgeRatings).run()
    }
}

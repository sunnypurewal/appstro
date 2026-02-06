import XCTest
import Foundation
@testable import AppstroCore

final class ModelTests: XCTestCase {
    func testAppstroConfigEncoding() throws {
        let config = AppstroConfig(
            name: "Test App",
            description: "A test description",
            keywords: ["test", "app"],
            bundleIdentifier: "com.test.app",
            appPath: ".",
            teamID: "TEAMID"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppstroConfig.self, from: data)
        
        XCTAssertEqual(config.name, decoded.name)
        XCTAssertEqual(config.description, decoded.description)
        XCTAssertEqual(config.keywords, decoded.keywords)
        XCTAssertEqual(config.bundleIdentifier, decoded.bundleIdentifier)
        XCTAssertEqual(config.appPath, decoded.appPath)
        XCTAssertEqual(config.teamID, decoded.teamID)
    }

    func testAppDetailsInitialization() {
        let details = AppDetails(
            id: "123",
            name: "App",
            bundleId: "com.app",
            appStoreUrl: "https://appstore.com/app",
            publishedVersion: "1.0.0"
        )
        XCTAssertEqual(details.id, "123")
        XCTAssertEqual(details.name, "App")
        XCTAssertEqual(details.bundleId, "com.app")
        XCTAssertEqual(details.appStoreUrl, "https://appstore.com/app")
        XCTAssertEqual(details.publishedVersion, "1.0.0")
    }

    func testAppInfoInitialization() {
        let info = AppInfo(
            id: "abc",
            name: "Test",
            bundleId: "com.test"
        )
        XCTAssertEqual(info.id, "abc")
        XCTAssertEqual(info.bundleId, "com.test")
        XCTAssertEqual(info.name, "Test")
    }

    func testAppPreferencesEncoding() throws {
        var prefs = AppPreferences()
        prefs.lastUsedPrefix = "test"
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(prefs)
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)
        
        XCTAssertEqual(prefs.lastUsedPrefix, decoded.lastUsedPrefix)
    }

    func testBuildInfoInitialization() {
        let build = BuildInfo(
            id: "build1",
            version: "1.0.0",
            processingState: .valid
        )
        XCTAssertEqual(build.id, "build1")
        XCTAssertEqual(build.version, "1.0.0")
        XCTAssertEqual(build.processingState, .valid)
    }

    func testContactInfoInitialization() {
        let contact = ContactInfo(
            firstName: "John",
            lastName: "Doe",
            email: "john@doe.com",
            phone: "123456789"
        )
        XCTAssertEqual(contact.firstName, "John")
    }

    func testContentRightsAnalysisEncoding() throws {
        let analysis = ContentRightsAnalysis(
            usesThirdPartyContent: true,
            reasoning: "Uses music"
        )
        let data = try JSONEncoder().encode(analysis)
        let decoded = try JSONDecoder().decode(ContentRightsAnalysis.self, from: data)
        XCTAssertEqual(analysis.usesThirdPartyContent, decoded.usesThirdPartyContent)
    }

    func testDataCollectionAnalysisEncoding() throws {
        let analysis = DataCollectionAnalysis(
            collectsData: true,
            dataTypes: CollectedDataTypes(
                location: true,
                contactInfo: false,
                healthAndFitness: false,
                financialInfo: false,
                userContent: false,
                browsingHistory: false,
                searchHistory: false,
                identifiers: true,
                usageData: true,
                diagnostics: true,
                otherData: false
            ),
            reasoning: "Uses analytics"
        )
        let data = try JSONEncoder().encode(analysis)
        let decoded = try JSONDecoder().decode(DataCollectionAnalysis.self, from: data)
        XCTAssertEqual(analysis.collectsData, decoded.collectsData)
        XCTAssertEqual(analysis.dataTypes.location, decoded.dataTypes.location)
    }

    func testDeviceBezelInfoInitialization() {
        let bezel = DeviceBezelInfo(
            name: "iPhone 15 Pro",
            displayType: "IPHONE_67",
            url: URL(string: "https://example.com")!,
            screenOffset: .zero,
            canvasSize: .zero,
            appStoreSize: .zero
        )
        XCTAssertEqual(bezel.name, "iPhone 15 Pro")
    }

    func testDraftVersionInitialization() {
        let draft = DraftVersion(
            version: "1.0.1",
            id: "draft1",
            state: .prepareForSubmission
        )
        XCTAssertEqual(draft.version, "1.0.1")
        XCTAssertEqual(draft.state, .prepareForSubmission)
    }

    func testGeneratedMetadataEncoding() throws {
        let meta = GeneratedMetadata(
            description: "Desc",
            keywords: "key, words",
            promotionalText: "Promo",
            reviewNotes: "Notes",
            whatsNew: "New"
        )
        let data = try JSONEncoder().encode(meta)
        let decoded = try JSONDecoder().decode(GeneratedMetadata.self, from: data)
        XCTAssertEqual(meta.description, decoded.description)
    }

    func testScreenshotConfigInitialization() {
        let config = ScreenshotConfig(
            filter: "filter",
            keyword: TextConfiguration(font: nil, font_size: 20, color: "#FFFFFF", weight: "bold"),
            title: nil,
            background_gradient: BackgroundGradient(start_color: "#000000", end_color: "#FFFFFF")
        )
        XCTAssertEqual(config.filter, "filter")
        XCTAssertEqual(config.keyword?.font_size, 20)
    }

    func testFramefileInitialization() {
        let config = ScreenshotConfig(filter: nil, keyword: nil, title: nil, background_gradient: nil)
        let framefile = Framefile(default_config: config, data: [config])
        XCTAssertEqual(framefile.data?.count, 1)
    }

    func testScreenshotDescriptionInitialization() {
        let desc = ScreenshotDescription(keyword: "key", title: "title")
        XCTAssertEqual(desc.keyword, "key")
        XCTAssertEqual(desc.title, "title")
    }

    func testSuggestedAgeRatingsEncoding() throws {
        let ratings = SuggestedAgeRatings(
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
            reasoning: "Safe"
        )
        let data = try JSONEncoder().encode(ratings)
        let decoded = try JSONDecoder().decode(SuggestedAgeRatings.self, from: data)
        XCTAssertEqual(ratings.reasoning, decoded.reasoning)
    }

    func testAppQueryInitialization() {
        let query = AppQuery(type: .name("test"))
        if case let .name(name) = query.type {
            XCTAssertEqual(name, "test")
        } else {
            XCTFail("Wrong query type")
        }
    }
}
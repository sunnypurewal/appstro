import XCTest
import AISDKProvider
import SwiftAISDK
@testable import AppstroAI
import AppstroCore

final class AIServiceTests: XCTestCase {
    func testInitWithNoKeysThrowsError() async {
        let service = DefaultAIService(model: nil)
        
        do {
            _ = try await service.generateMetadata(appName: "Test", codeContext: "Code", userPitch: String?.none)
            XCTFail("Should have thrown error")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "AIService")
            XCTAssertEqual(nsError.code, 1)
        }
    }

    func testGenerateMetadataWithMock() async throws {
        let jsonResponse = """
        {
            "description": "Mock Desc",
            "keywords": "mock, keys",
            "promotionalText": "Mock Promo",
            "whatsNew": "Mock New",
            "reviewNotes": "Mock Notes"
        }
        """
        
        let mockModel = MockLanguageModelV3(
            doGenerate: .function { options in
                return LanguageModelV3GenerateResult(
                    content: [.text(LanguageModelV3Text(text: jsonResponse))],
                    finishReason: .stop,
                    usage: LanguageModelV3Usage(
                        inputTokens: 10,
                        outputTokens: 20
                    )
                )
            }
        )
        
        let service = DefaultAIService(model: mockModel)
        let metadata = try await service.generateMetadata(appName: "Test", codeContext: "context", userPitch: String?.none)
        
        XCTAssertEqual(metadata.description, "Mock Desc")
        XCTAssertEqual(metadata.keywords, "mock, keys")
    }

    func testAnalyzeContentRights() async throws {
        let jsonResponse = """
        {
            "usesThirdPartyContent": true,
            "reasoning": "Uses music"
        }
        """
        let mockModel = MockLanguageModelV3(
            doGenerate: .function { _ in
                return LanguageModelV3GenerateResult(
                    content: [.text(LanguageModelV3Text(text: jsonResponse))],
                    finishReason: .stop,
                    usage: LanguageModelV3Usage()
                )
            }
        )
        let service = DefaultAIService(model: mockModel)
        let analysis = try await service.analyzeContentRights(appName: "Test", description: "Desc")
        XCTAssertTrue(analysis?.usesThirdPartyContent ?? false)
    }

    func testSuggestAgeRatings() async throws {
        let jsonResponse = """
        {
            "alcoholTobaccoOrDrugUseOrReference": "NONE",
            "gamblingAndContests": false,
            "gamblingSimulated": "NONE",
            "horrorOrFearThemes": "NONE",
            "matureOrSuggestiveThemes": "NONE",
            "medicalOrTreatmentInformation": "NONE",
            "profanityOrCrudeHumor": "NONE",
            "sexualContentOrNudity": "NONE",
            "sexualContentGraphicOrNudity": "NONE",
            "violenceCartoonOrFantasy": "NONE",
            "violenceRealistic": "NONE",
            "violenceRealisticProlongedGraphicOrSadistic": "NONE",
            "gunsOrOtherWeapons": "NONE",
            "parentalControls": false,
            "userGeneratedContent": false,
            "ageAssurance": false,
            "advertising": false,
            "healthOrWellnessTopics": false,
            "messagingAndChat": "NONE",
            "unrestrictedWebAccess": false,
            "kids17Plus": false,
            "isLootBox": false,
            "kidsAgeBand": null,
            "koreaAgeRatingOverride": "NONE",
            "reasoning": "Safe"
        }
        """
        let mockModel = MockLanguageModelV3(
            doGenerate: .function { _ in
                return LanguageModelV3GenerateResult(
                    content: [.text(LanguageModelV3Text(text: jsonResponse))],
                    finishReason: .stop,
                    usage: LanguageModelV3Usage()
                )
            }
        )
        let service = DefaultAIService(model: mockModel)
        let ratings = try await service.suggestAgeRatings(appName: "Test", description: "Desc", codeContext: "Code")
        XCTAssertEqual(ratings?.reasoning, "Safe")
    }

    func testAnalyzeDataCollection() async throws {
        let jsonResponse = """
        {
            "collectsData": false,
            "reasoning": "None found",
            "dataTypes": {
                "location": false,
                "contactInfo": false,
                "healthAndFitness": false,
                "financialInfo": false,
                "userContent": false,
                "browsingHistory": false,
                "searchHistory": false,
                "identifiers": false,
                "usageData": false,
                "diagnostics": false,
                "otherData": false
            }
        }
        """
        let mockModel = MockLanguageModelV3(
            doGenerate: .function { _ in
                return LanguageModelV3GenerateResult(
                    content: [.text(LanguageModelV3Text(text: jsonResponse))],
                    finishReason: .stop,
                    usage: LanguageModelV3Usage()
                )
            }
        )
        let service = DefaultAIService(model: mockModel)
        let analysis = try await service.analyzeDataCollection(appName: "Test", codeContext: "Code")
        XCTAssertFalse(analysis?.collectsData ?? true)
    }

    func testDescribeScreenshot() async throws {
        let jsonResponse = """
        {
            "keyword": "mock",
            "title": "Mock Title"
        }
        """
        let mockModel = MockLanguageModelV3(
            doGenerate: .function { _ in
                return LanguageModelV3GenerateResult(
                    content: [.text(LanguageModelV3Text(text: jsonResponse))],
                    finishReason: .stop,
                    usage: LanguageModelV3Usage()
                )
            }
        )
        // describeScreenshot uses generateText which calls doGenerate on the model if wrapped correctly?
        // Wait, DefaultAIService.swift uses generateText for describeScreenshot.
        // let result: DefaultGenerateTextResult<JSONValue> = try await generateText(model: .v3(model), messages: [userMessage])
        
        let service = DefaultAIService(model: mockModel)
        
        // We need a dummy image file
        let tempImageURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.png")
        try Data().write(to: tempImageURL)
        defer { try? FileManager.default.removeItem(at: tempImageURL) }

        let description = try await service.describeScreenshot(imageURL: tempImageURL, appName: "Test", appDescription: "Desc")
        XCTAssertEqual(description.keyword, "mock")
    }
}

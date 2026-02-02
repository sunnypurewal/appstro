import Foundation
import SwiftAISDK
import OpenAIProvider
import AnthropicProvider
import GoogleProvider

final class AIService {
    private let model: (any LanguageModelV3)?

    init() {
        if let _ = ProcessInfo.processInfo.environment["GOOGLE_GENERATIVE_AI_API_KEY"] ?? ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
            self.model = try? google("gemini-2.0-flash")
        } else if let _ = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            self.model = try? anthropic("claude-3-5-sonnet-latest")
        } else if let _ = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            self.model = try? openai("gpt-4o")
        } else {
            self.model = nil
        }
    }

    func generateMetadata(appName: String, codeContext: String, userPitch: String?) async throws -> GeneratedMetadata {
        guard let model = model else {
            throw NSError(domain: "AIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No AI API key found in environment variables (GEMINI_API_KEY, ANTHROPIC_API_KEY, or OPENAI_API_KEY)."])
        }

        let pitch = userPitch ?? "A high-quality iOS app."
        let prompt = """
        You are an expert App Store Optimizer and copywriter.
        Based on the following information, generate metadata for an iOS app named "\(appName)".

        App Code Context (SwiftUI):
        \(codeContext)

        User's Pitch/Description:
        \(pitch)

        Provide:
        1. description: A compelling app store description (max 4000 characters).
        2. keywords: A comma-separated list of relevant keywords (max 100 characters total).
        3. promotionalText: A catchy promotional snippet (max 170 characters).
        4. reviewNotes: Information for the App Store reviewer explaining that no login is required and any other technical details derived from the code.
        """

        let result = try await generateObject(
            model: model,
            schema: GeneratedMetadata.self,
            prompt: prompt,
            schemaName: "app_metadata"
        )

                return result.object

            }

        

            func analyzeContentRights(appName: String, description: String) async throws -> ContentRightsAnalysis? {

                guard let model = model else { return nil }

        

                let prompt = """

                Analyze the following app description and determine if the app contains, displays, or accesses third-party content (like music, movies, news, or other copyrighted material).

                

                App Name: \(appName)

                Description: \(description)

                

                Provide:

                1. usesThirdPartyContent: true if it likely uses third-party content, false otherwise.

                2. reasoning: A brief explanation for your decision.

                """

        

                let result = try await generateObject(

                    model: model,

                    schema: ContentRightsAnalysis.self,

                    prompt: prompt,

                    schemaName: "content_rights"

                )

                return result.object

            }

        

            func suggestAgeRatings(appName: String, description: String, codeContext: String) async throws -> SuggestedAgeRatings? {

                guard let model = model else { return nil }

        

                let prompt = """

                Based on the app description and code context, suggest age ratings for the following iOS app.

                

                App Name: \(appName)

                Description: \(description)

                Code Context:

                \(codeContext)

                

                For each category, use "NONE", "INFREQUENT_MILD", or "FREQUENT_INTENSE".

                For boolean values, use true or false.

                

                Categories:

                - alcoholTobaccoOrDrugUseOrReference

                - gamblingAndContests (Boolean)

                - gamblingSimulated

                - horrorOrFearThemes

                - matureOrSuggestiveThemes

                - medicalOrTreatmentInformation

                - profanityOrCrudeHumor

                - sexualContentOrNudity

                - sexualContentGraphicOrNudity

                - violenceCartoonOrFantasy

                        - violenceRealistic

                                - violenceRealisticProlongedGraphicOrSadistic

                                - unrestrictedWebAccess (Boolean)

                                - kids17Plus (Boolean)

                                - isLootBox (Boolean): true if the app contains loot boxes or other randomized in-app purchases.

                                - kidsAgeBand: "FIVE_AND_UNDER", "SIX_TO_EIGHT", or "NINE_TO_ELEVEN" if the app is specifically for children, otherwise null.

                                - koreaAgeRatingOverride: "NONE", "FIFTEEN_PLUS", or "NINETEEN_PLUS" (Defaults to "NONE").

                                

                                Provide reasoning for the suggestions.

                        

                

                """

        

                let result = try await generateObject(

                    model: model,

                    schema: SuggestedAgeRatings.self,

                    prompt: prompt,

                    schemaName: "age_ratings"

                )

                return result.object

            }

        }

        
import AppstroCore
import Foundation
import SwiftAISDK
import OpenAIProvider
import AnthropicProvider
import GoogleProvider

public final class DefaultAIService: AIService {
	private let model: (any LanguageModelV3)?

	public init(model: (any LanguageModelV3)? = nil) {
		if let model = model {
			self.model = model
		} else if let _ = ProcessInfo.processInfo.environment["GOOGLE_GENERATIVE_AI_API_KEY"] ?? ProcessInfo.processInfo.environment["GEMINI_API_KEY"] {
			self.model = try? google("gemini-2.0-flash")
		} else if let _ = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
			self.model = try? anthropic("claude-3-5-sonnet-latest")
		} else if let _ = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
			self.model = try? openai("gpt-4o")
		} else {
			self.model = nil
		}
	}

	public func generateMetadata(appName: String, codeContext: String, userPitch: String?) async throws -> GeneratedMetadata {
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
			4. whatsNew: A brief "What's New in this Version" summary. If it's the first version, use "Initial release". (max 4000 characters).
			5. reviewNotes: Information for the App Store reviewer explaining that no login is required and any other technical details derived from the code.
			"""

		let result = try await generateObject(
			model: model,
			schema: GeneratedMetadata.self,
			prompt: prompt,
			schemaName: "app_metadata"
		)

		return result.object
	}

	public func analyzeContentRights(appName: String, description: String) async throws -> ContentRightsAnalysis? {
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

	public func suggestAgeRatings(appName: String, description: String, codeContext: String) async throws -> SuggestedAgeRatings? {
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
			- gunsOrOtherWeapons
			- parentalControls (Boolean)
			- userGeneratedContent (Boolean)
			- ageAssurance (Boolean)
			- advertising (Boolean)
			- healthOrWellnessTopics (Boolean)
			- messagingAndChat
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

	public func analyzeDataCollection(appName: String, codeContext: String) async throws -> DataCollectionAnalysis? {
		guard let model = model else { return nil }

		let prompt = """
			You are an expert in Apple's App Store Privacy guidelines. 
			Analyze the provided Swift code for "\(appName)" to determine if it collects data as defined by Apple.

			--- APPLE'S DEFINITIONS ---
			1. "Collect" refers to transmitting data off the device in a way that allows you and/or your third-party partners to access it for a period longer than what is necessary to service the transmitted request in real time.
			2. "Third-party partners" refers to analytics tools, advertising networks, third-party SDKs, or other external vendors whose code you’ve added to your app.
			
			--- OPTIONAL DISCLOSURE (You may answer 'No' if ALL of the following apply) ---
			- The data is NOT used for tracking, advertising, or marketing.
			- Collection is infrequent, not part of primary functionality, and optional for the user.
			- The data is provided by the user in the UI, where it's clear what is being collected, and the user affirmatively chooses to provide it each time.
			- The user's name or account name is prominently displayed in the submission form alongside the data being submitted.

			--- YOUR TASK ---
			Focus on identifying:
			- Networking code (URLSession, etc.) sending user or device data to external servers.
			- Third-party SDKs (Firebase, Mixpanel, AdMob, etc.).
			- Local processing (like on-device Vision, CoreML, or Camera usage) that DOES NOT transmit data off-device should be marked as NOT collecting data unless you see a subsequent network request transmitting that data.

			App Code Context (SwiftUI):
			\(codeContext)

			Provide a JSON object with:
			1. collectsData: true if any data is transmitted off-device and does not meet ALL 'Optional Disclosure' criteria.
			2. reasoning: A brief explanation for your assessment. Mention specifically if you found network transmissions or third-party SDKs.
			3. dataTypes: An object containing the following boolean fields:
			   - location
			   - contactInfo
			   - healthAndFitness
			   - financialInfo
			   - userContent
			   - browsingHistory
			   - searchHistory
			   - identifiers
			   - usageData
			   - diagnostics
			   - otherData
			"""

		let result = try await generateObject(
			model: model,
			schema: DataCollectionAnalysis.self,
			prompt: prompt,
			schemaName: "data_collection_analysis"
		)
		return result.object
	}

	public func describeScreenshot(imageURL: URL, appName: String, appDescription: String) async throws -> ScreenshotDescription {
		guard let model = model else {
			return ScreenshotDescription(keyword: "screenshot", title: "TODO: Title")
		}

		let imageData = try Data(contentsOf: imageURL)
		let mimeType: String = if imageURL.pathExtension.lowercased() == "png" { "image/png" } else { "image/jpeg" }

		let promptText = """
			Analyze the provided screenshot for the iOS app "\(appName)". 
			App Description: \(appDescription)
			
			Return a JSON object with:
			1. keyword: EXACTLY ONE WORD that describes what is shown (e.g., "Login", "Dashboard", "Profile"). This will be used as a filename.
			2. title: A compelling marketing title for this screen (e.g., "Secure Login", "Your Dashboard", "Personal Profile"). Max 50 characters.

			Example: {"keyword": "login", "title": "Secure Login"}
			"""

		let userMessage = ModelMessage.user(UserModelMessage(content: .parts([
			.text(TextPart(text: promptText)),
			.image(ImagePart(image: .data(imageData), mediaType: mimeType))
		])))

		let result: DefaultGenerateTextResult<JSONValue> = try await generateText(
			model: .v3(model),
			messages: [userMessage]
		)

		let cleanedJSON = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
			.replacingOccurrences(of: "```json", with: "")
			.replacingOccurrences(of: "```", with: "")
		
		guard let data = cleanedJSON.data(using: .utf8),
		      let description = try? JSONDecoder().decode(ScreenshotDescription.self, from: data) else {
			return ScreenshotDescription(keyword: "screenshot", title: "App Screenshot")
		}

		return description
	}
}

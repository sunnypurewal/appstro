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
}
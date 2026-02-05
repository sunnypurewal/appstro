import Foundation
import AppstroCore
import AppstroAI
import AppstroServices

public struct Environment: Sendable {
	public let ai: any AIService
	public let project: any ProjectService
	public let bezel: any BezelService
	public let imageProcessor: any ImageProcessor
	public let queryInterpreter: any AppQueryInterpreter
	public let preferences: any PreferenceService
	
	public init(
		ai: any AIService = DefaultAIService(),
		project: any ProjectService = FileSystemProjectService(),
		bezel: any BezelService = DefaultBezelService(),
		imageProcessor: any ImageProcessor = DefaultImageProcessor(),
		queryInterpreter: any AppQueryInterpreter = DefaultAppQueryInterpreter(),
		preferences: any PreferenceService = FilePreferenceService()
	) {
		self.ai = ai
		self.project = project
		self.bezel = bezel
		self.imageProcessor = imageProcessor
		self.queryInterpreter = queryInterpreter
		self.preferences = preferences
	}
	
	public static nonisolated(unsafe) var live = Environment()
}
import Foundation
import AppstroCore
import AppstroAI
import AppstroASC
import AppstroServices

public struct Environment: Sendable {
	public let ai: any AIService
	public let project: any ProjectService
	public let bezel: any BezelService
	public let imageProcessor: any ImageProcessor
	public let queryInterpreter: any AppQueryInterpreter
	public let preferences: any PreferenceService
	public let ui: any UserInterface
	public let uploader: any BuildUploader
	public let asc: @Sendable (any BezelService) throws -> any AppStoreConnectService
	
	public init(
		ai: any AIService = DefaultAIService(),
		project: any ProjectService = FileSystemProjectService(),
		bezel: any BezelService = DefaultBezelService(),
		imageProcessor: any ImageProcessor = DefaultImageProcessor(),
		queryInterpreter: any AppQueryInterpreter = DefaultAppQueryInterpreter(),
		preferences: any PreferenceService = FilePreferenceService(),
		ui: any UserInterface = DefaultUI(),
		uploader: any BuildUploader = DefaultBuildUploader(),
		asc: @Sendable @escaping (any BezelService) throws -> any AppStoreConnectService = { try ASCServiceFactory.makeService(bezelService: $0) }
	) {
		self.ai = ai
		self.project = project
		self.bezel = bezel
		self.imageProcessor = imageProcessor
		self.queryInterpreter = queryInterpreter
		self.preferences = preferences
		self.ui = ui
		self.uploader = uploader
		self.asc = asc
	}
	
	public static nonisolated(unsafe) var live = Environment()
}
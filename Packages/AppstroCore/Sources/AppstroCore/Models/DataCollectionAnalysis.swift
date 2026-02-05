import Foundation

public struct DataCollectionAnalysis: Codable, Sendable {
	public let collectsData: Bool
	public let dataTypes: CollectedDataTypes
	public let reasoning: String

	public init(collectsData: Bool, dataTypes: CollectedDataTypes, reasoning: String) {
		self.collectsData = collectsData
		self.dataTypes = dataTypes
		self.reasoning = reasoning
	}
}

public struct CollectedDataTypes: Codable, Sendable {
	public let location: Bool
	public let contactInfo: Bool
	public let healthAndFitness: Bool
	public let financialInfo: Bool
	public let userContent: Bool
	public let browsingHistory: Bool
	public let searchHistory: Bool
	public let identifiers: Bool
	public let usageData: Bool
	public let diagnostics: Bool
	public let otherData: Bool

	public init(
		location: Bool,
		contactInfo: Bool,
		healthAndFitness: Bool,
		financialInfo: Bool,
		userContent: Bool,
		browsingHistory: Bool,
		searchHistory: Bool,
		identifiers: Bool,
		usageData: Bool,
		diagnostics: Bool,
		otherData: Bool
	) {
		self.location = location
		self.contactInfo = contactInfo
		self.healthAndFitness = healthAndFitness
		self.financialInfo = financialInfo
		self.userContent = userContent
		self.browsingHistory = browsingHistory
		self.searchHistory = searchHistory
		self.identifiers = identifiers
		self.usageData = usageData
		self.diagnostics = diagnostics
		self.otherData = otherData
	}
}

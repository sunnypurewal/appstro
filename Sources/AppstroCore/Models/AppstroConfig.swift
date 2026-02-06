import Foundation

public struct AppstroConfig: Codable, Sendable {
	public let name: String
	public let description: String
	public let keywords: [String]
	public let bundleIdentifier: String?
	public let appPath: String?
	public let teamID: String?

	public enum CodingKeys: String, CodingKey {
		case name
		case description
		case keywords
		case bundleIdentifier = "bundle_identifier"
		case appPath = "app_path"
		case teamID = "team_id"
	}

	public init(name: String, description: String, keywords: [String] = [], bundleIdentifier: String? = nil, appPath: String?, teamID: String? = nil) {
		self.name = name
		self.description = description
		self.keywords = keywords
		self.bundleIdentifier = bundleIdentifier
		self.appPath = appPath
		self.teamID = teamID
	}
}

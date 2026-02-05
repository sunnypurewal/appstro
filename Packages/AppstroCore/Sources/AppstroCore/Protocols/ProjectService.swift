import Foundation

public protocol ProjectService: Sendable {
	func findProjectRoot() -> URL?
	func loadConfig(at root: URL) throws -> AppstroConfig
	func saveConfig(_ config: AppstroConfig, at root: URL) throws
	func containsXcodeProject(at url: URL) -> String?
	func getBundleIdentifier(at url: URL) -> String?
	func getTeamID(at url: URL) -> String?
	func ensureAppstroDirectory(at root: URL) throws -> URL
	func ensureReleaseDirectory(at root: URL, version: String) throws -> URL
	func setupGitIgnore(at root: URL) async throws
	func build(at root: URL, config: AppstroConfig, version: String, buildNumber: String) async throws -> URL
}

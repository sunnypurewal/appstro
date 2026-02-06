import Foundation

public protocol PricingService: Sendable {
	func fetchCurrentPriceDescription(appId: String) async throws -> String?
	func fetchCurrentPriceSchedule(appId: String) async throws -> Set<String>
	func fetchAppPricePoints(appId: String) async throws -> [String]
	func updateAppPrice(appId: String, tier: String) async throws
}

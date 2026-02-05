import Foundation

public protocol BezelService: Sendable {
	func bezelInfo(for deviceType: String) -> DeviceBezelInfo?
	func downloadBezelIfNeeded(for info: DeviceBezelInfo) async throws -> URL
}

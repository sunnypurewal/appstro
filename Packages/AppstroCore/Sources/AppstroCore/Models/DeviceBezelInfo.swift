import Foundation

public struct DeviceBezelInfo: Sendable {
	public let name: String
	public let displayType: String // App Store Connect Display Type
	public let url: URL
	public let screenOffset: NSRect
	public let canvasSize: CGSize
	public let appStoreSize: CGSize // The final required size for ASC

	public init(name: String, displayType: String, url: URL, screenOffset: NSRect, canvasSize: CGSize, appStoreSize: CGSize) {
		self.name = name
		self.displayType = displayType
		self.url = url
		self.screenOffset = screenOffset
		self.canvasSize = canvasSize
		self.appStoreSize = appStoreSize
	}
}

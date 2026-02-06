import Foundation

public protocol ImageProcessor: Sendable {
	func process(
		screenshotURL: URL,
		bezelURL: URL,
		bezelInfo: DeviceBezelInfo,
		config: ScreenshotConfig,
		defaultConfig: ScreenshotConfig,
		keywordText: String,
		titleText: String,
		outputURL: URL
	) throws
}

import Foundation

public struct ScreenshotConfig: Codable, Sendable {
	public let filter: String?			 // Key for title.strings
	public let keyword: TextConfiguration? // Nested text config for keyword
	public let title: TextConfiguration?   // Nested text config for title
	public let background_gradient: BackgroundGradient?

	public init(filter: String?, keyword: TextConfiguration?, title: TextConfiguration?, background_gradient: BackgroundGradient?) {
		self.filter = filter
		self.keyword = keyword
		self.title = title
		self.background_gradient = background_gradient
	}
}

public struct TextConfiguration: Codable, Sendable {
	public let font: String?		// Path to font file or system font name
	public let font_size: CGFloat?  // Font size
	public let color: String?	   // Hex color string
	public let weight: String?	  // e.g., "bold", "regular", "light" (for system fonts)

	public init(font: String?, font_size: CGFloat?, color: String?, weight: String?) {
		self.font = font
		self.font_size = font_size
		self.color = color
		self.weight = weight
	}
}

public struct BackgroundGradient: Codable, Sendable {
	public let start_color: String
	public let end_color: String

	public init(start_color: String, end_color: String) {
		self.start_color = start_color
		self.end_color = end_color
	}
}

public struct Framefile: Codable, Sendable {
	public let default_config: ScreenshotConfig
	public let data: [ScreenshotConfig]?

	public init(default_config: ScreenshotConfig, data: [ScreenshotConfig]?) {
		self.default_config = default_config
		self.data = data
	}
}

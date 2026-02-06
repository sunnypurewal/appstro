import AppstroCore
import Foundation
import AppKit
import CoreGraphics

public final class DefaultImageProcessor: ImageProcessor {
	
	public init() {}
	
	public func process(
		screenshotURL: URL,
		bezelURL: URL,
		bezelInfo: DeviceBezelInfo,
		config: ScreenshotConfig,
		defaultConfig: ScreenshotConfig,
		keywordText: String,
		titleText: String,
		outputURL: URL
	) throws {
		guard let screenshot = NSImage(contentsOf: screenshotURL) else {
			throw NSError(domain: "ImageProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load screenshot at \(screenshotURL.path)"])
		}
		guard let bezel = NSImage(contentsOf: bezelURL) else {
			throw NSError(domain: "ImageProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load bezel at \(bezelURL.path)"])
		}
		
		let screenshotPixels = screenshot.representations.first.map { CGSize(width: $0.pixelsWide, height: $0.pixelsHigh) } ?? screenshot.size
		let finalCanvasSize = bezelInfo.appStoreSize
		
		guard let offscreenRep = NSBitmapImageRep(
			bitmapDataPlanes: nil,
			pixelsWide: Int(finalCanvasSize.width),
			pixelsHigh: Int(finalCanvasSize.height),
			bitsPerSample: 8,
			samplesPerPixel: 4,
			hasAlpha: true,
			isPlanar: false,
			colorSpaceName: .deviceRGB,
			bytesPerRow: 0,
			bitsPerPixel: 0
		) else {
			throw NSError(domain: "ImageProcessor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap representation"])
		}
		
		let graphicsContext = NSGraphicsContext(bitmapImageRep: offscreenRep)!
		NSGraphicsContext.saveGraphicsState()
		NSGraphicsContext.current = graphicsContext
		
		let fullRect = NSRect(origin: .zero, size: finalCanvasSize)

		let gradientConfig = config.background_gradient ?? defaultConfig.background_gradient
		if let gradientConfig = gradientConfig {
			let startColor = hexColor(gradientConfig.start_color)
			let endColor = hexColor(gradientConfig.end_color)
			let gradient = NSGradient(starting: startColor, ending: endColor)
			gradient?.draw(in: fullRect, angle: 90)
		} else {
			NSColor.black.set()
			fullRect.fill()
		}
		
		let textAreaHeight = finalCanvasSize.height * 0.20
		let padding = finalCanvasSize.width * 0.05
		let availableWidth = finalCanvasSize.width - (padding * 2)
		let availableHeight = finalCanvasSize.height - textAreaHeight - (padding * 2)
		
		let bezelSize = bezelInfo.canvasSize
		let scaleX = availableWidth / bezelSize.width
		let scaleY = availableHeight / bezelSize.height
		let scale = min(scaleX, scaleY)
		
		let scaledBezelWidth = bezelSize.width * scale
		let scaledBezelHeight = bezelSize.height * scale
		
		let bezelRect = NSRect(
			x: (finalCanvasSize.width - scaledBezelWidth) / 2,
			y: padding,
			width: scaledBezelWidth,
			height: scaledBezelHeight
		)
		
		NSGraphicsContext.saveGraphicsState()
		let transform = NSAffineTransform()
		transform.translateX(by: bezelRect.origin.x, yBy: bezelRect.origin.y)
		transform.scale(by: scale)
		transform.concat()
		
		let screenRect = bezelInfo.screenOffset
		NSGraphicsContext.saveGraphicsState()
		let clipPath: NSBezierPath
		
		if bezelInfo.displayType.contains("IPHONE") {
			clipPath = NSBezierPath(roundedRect: screenRect, xRadius: 189, yRadius: 189)
		} else {
			clipPath = NSBezierPath(roundedRect: screenRect, xRadius: 109, yRadius: 109)
		}
		clipPath.addClip()
		
		let screenshotPadding: CGFloat = bezelInfo.displayType.contains("IPHONE") ? 0 : 100
		let paddedScreenRect = screenRect.insetBy(dx: screenshotPadding, dy: screenshotPadding)
		
		let targetSize = paddedScreenRect.size
		let widthRatio = targetSize.width / screenshotPixels.width
		let heightRatio = targetSize.height / screenshotPixels.height
		let ratio = min(widthRatio, heightRatio)
		let drawWidth = screenshotPixels.width * ratio
		let drawHeight = screenshotPixels.height * ratio
		
		let drawRect = NSRect(
			x: paddedScreenRect.origin.x + (targetSize.width - drawWidth) / 2,
			y: paddedScreenRect.origin.y + (targetSize.height - drawHeight) / 2,
			width: drawWidth,
			height: drawHeight
		)
		
		screenshot.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
		NSGraphicsContext.restoreGraphicsState()
		
		bezel.draw(in: NSRect(origin: .zero, size: bezelSize))
		NSGraphicsContext.restoreGraphicsState()
		
		if !keywordText.isEmpty || !titleText.isEmpty {
			let defaultFontSize = finalCanvasSize.height * 0.04
			
			func resolveFont(config: TextConfiguration?, fallback: TextConfiguration?, defaultWeight: NSFont.Weight) -> (font: NSFont, color: NSColor) {
				let fontSize = config?.font_size ?? fallback?.font_size ?? defaultFontSize
				let fontColor = hexColor(config?.color ?? fallback?.color ?? "FFFFFF")
				let fontName = config?.font ?? fallback?.font
				var resolvedFont: NSFont
				
				if let fontPath = fontName {
					let fontURL = URL(fileURLWithPath: fontPath)
					if let descriptors = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor],
					   let descriptor = descriptors.first {
						resolvedFont = NSFont(descriptor: descriptor, size: fontSize) ?? .systemFont(ofSize: fontSize, weight: defaultWeight)
					} else if let systemFont = NSFont(name: fontPath, size: fontSize) {
						resolvedFont = systemFont
					} else {
						resolvedFont = .systemFont(ofSize: fontSize, weight: defaultWeight)
					}
				} else {
					let fontWeight: NSFont.Weight
					let weightStr = config?.weight ?? fallback?.weight
					switch weightStr?.lowercased() {
					case "bold": fontWeight = .bold
					case "light": fontWeight = .light
					default: fontWeight = defaultWeight
					}
					resolvedFont = .systemFont(ofSize: fontSize, weight: fontWeight)
				}
				return (resolvedFont, fontColor)
			}
			
			let (keywordFont, keywordColor) = resolveFont(config: config.keyword, fallback: defaultConfig.keyword, defaultWeight: .bold)
			let (titleFont, titleColor) = resolveFont(config: config.title, fallback: defaultConfig.title, defaultWeight: .regular)
			
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.alignment = .center
			paragraphStyle.lineBreakMode = .byWordWrapping

			let combinedString = NSMutableAttributedString()
			
			if !keywordText.isEmpty {
				combinedString.append(NSAttributedString(string: keywordText.uppercased(), attributes: [
					.font: keywordFont,
					.foregroundColor: keywordColor,
					.paragraphStyle: paragraphStyle
				]))
				combinedString.append(NSAttributedString(string: " ", attributes: [
					.font: titleFont,
					.foregroundColor: titleColor,
					.paragraphStyle: paragraphStyle
				]))
			}
			
			if !titleText.isEmpty {
				combinedString.append(NSAttributedString(string: titleText, attributes: [
					.font: titleFont,
					.foregroundColor: titleColor,
					.paragraphStyle: paragraphStyle
				]))
			}
			
			let textWidth = scaledBezelWidth
			let constraintSize = CGSize(width: textWidth, height: textAreaHeight)
			let boundingRect = combinedString.boundingRect(with: constraintSize, options: [.usesLineFragmentOrigin, .usesFontLeading])
			
			let textRect = NSRect(
				x: (finalCanvasSize.width - textWidth) / 2,
				y: finalCanvasSize.height - textAreaHeight + (textAreaHeight - boundingRect.height) / 2,
				width: textWidth,
				height: boundingRect.height
			)
			
			combinedString.draw(in: textRect)
		}
		
		NSGraphicsContext.restoreGraphicsState()
		
		offscreenRep.size = finalCanvasSize
		offscreenRep.hasAlpha = false
		
		if let data = offscreenRep.representation(using: NSBitmapImageRep.FileType.png, properties: [.interlaced: false]) {
			try data.write(to: outputURL)
		}
	}
	
	private func hexColor(_ hex: String) -> NSColor {
		var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
		hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
		
		var rgb: UInt64 = 0
		Scanner(string: hexSanitized).scanHexInt64(&rgb)
		
		let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
		let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
		let b = CGFloat(rgb & 0x0000FF) / 255.0
		
		return NSColor(red: r, green: g, blue: b, alpha: 1.0)
	}
}
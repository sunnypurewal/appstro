import AppstroCore
import Foundation
import CoreGraphics
import AppKit

public final class DefaultBezelService: BezelService {
	
	public init() {}
	
	public func bezelInfo(for deviceType: String, isLandscape: Bool) -> DeviceBezelInfo? {
		switch deviceType.lowercased() {
		case "iphone":
			return DeviceBezelInfo(
				name: "iPhone 13 Pro Max",
				displayType: "IPHONE_67",
				url: URL(string: "iphone-portrait-gray.png")!,
				screenOffset: NSRect(x: 75, y: 66, width: 1320, height: 2868),
				canvasSize: CGSize(width: 1470, height: 3000),
				appStoreSize: CGSize(width: 1290, height: 2796)
			)
		case "ipad":
			if isLandscape {
				return DeviceBezelInfo(
					name: "iPad Pro 12.9 (Landscape)",
					displayType: "IPAD_PRO_3GEN_129",
					url: URL(string: "ipad-landscape-gray.png")!,
					screenOffset: NSRect(x: 100, y: 100, width: 2732, height: 2048),
					canvasSize: CGSize(width: 2932, height: 2248),
					appStoreSize: CGSize(width: 2752, height: 2064)
				)
			} else {
				return DeviceBezelInfo(
					name: "iPad Pro 12.9 (Portrait)",
					displayType: "IPAD_PRO_3GEN_129",
					url: URL(string: "ipad-portrait-gray.png")!,
					screenOffset: NSRect(x: 100, y: 100, width: 2048, height: 2732),
					canvasSize: CGSize(width: 2248, height: 2932),
					appStoreSize: CGSize(width: 2064, height: 2752)
				)
			}
		default:
			return nil
		}
	}

	public func downloadBezelIfNeeded(for info: DeviceBezelInfo) async throws -> URL {
		let filename = info.url.lastPathComponent
		let nameWithoutExtension = (filename as NSString).deletingPathExtension
		let extensionName = (filename as NSString).pathExtension
		
		guard let localURL = Bundle.module.url(forResource: nameWithoutExtension, withExtension: extensionName) else {
			throw NSError(domain: "BezelService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Bezel image '\(nameWithoutExtension).\(extensionName)' not found in bundled resources."])
		}
		
		guard let image = NSImage(contentsOf: localURL), image.isValid else {
			throw NSError(domain: "BezelService", code: 1, userInfo: [NSLocalizedDescriptionKey: "The bundled bezel image at \(localURL.path) is invalid or corrupted."])
		}
		
		return localURL
	}
}
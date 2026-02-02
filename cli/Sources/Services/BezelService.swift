import Foundation
import CoreGraphics
import AppKit

struct DeviceBezelInfo: Sendable {
    let name: String
    let displayType: String // App Store Connect Display Type
    let url: URL
    let screenOffset: NSRect
    let canvasSize: CGSize
    let appStoreSize: CGSize // The final required size for ASC
}

final class BezelService: Sendable {
    
    init() {}
    
    private let devices: [String: DeviceBezelInfo] = [
        "iphone": DeviceBezelInfo(
            name: "iPhone 13 Pro Max",
            displayType: "IPHONE_67",
            url: URL(fileURLWithPath: "iphone-portrait-gray.png"),
            screenOffset: NSRect(x: 75, y: 66, width: 1320, height: 2868),
            canvasSize: CGSize(width: 1470, height: 3000),
            appStoreSize: CGSize(width: 1290, height: 2796)
        ),
        "ipad": DeviceBezelInfo(
            name: "iPad Pro 12.9",
            displayType: "IPAD_PRO_3GEN_129",
            url: URL(fileURLWithPath: "ipad-landscape-gray.png"),
            screenOffset: NSRect(x: 100, y: 100, width: 2732, height: 2048),
            canvasSize: CGSize(width: 2932, height: 2248),
            appStoreSize: CGSize(width: 2752, height: 2064)
        )
    ]

    func bezelInfo(for deviceType: String) -> DeviceBezelInfo? {
        return devices[deviceType.lowercased()]
    }

    func downloadBezelIfNeeded(for info: DeviceBezelInfo) async throws -> URL {
        let filename = info.url.deletingPathExtension().lastPathComponent
        let ext = info.url.pathExtension
        
        guard let localURL = Bundle.module.url(forResource: filename, withExtension: ext) else {
            throw NSError(domain: "BezelService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Bezel image '\(filename).\(ext)' not found in bundled resources."])
        }
        
        guard let image = NSImage(contentsOf: localURL), image.isValid else {
            throw NSError(domain: "BezelService", code: 1, userInfo: [NSLocalizedDescriptionKey: "The bundled bezel image at \(localURL.path) is invalid or corrupted."])
        }
        
        return localURL
    }
}


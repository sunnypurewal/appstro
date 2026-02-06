import XCTest
@testable import AppstroServices
import AppstroCore

final class BezelServiceTests: XCTestCase {
    func testBezelInfoRetrieval() {
        let service = DefaultBezelService()
        XCTAssertNotNil(service.bezelInfo(for: "iphone", isLandscape: false))
        XCTAssertNotNil(service.bezelInfo(for: "ipad", isLandscape: false))
        XCTAssertNotNil(service.bezelInfo(for: "ipad", isLandscape: true))
        XCTAssertNil(service.bezelInfo(for: "unknown", isLandscape: false))
    }

    func testBezelInfoCaseInsensitivity() {
        let service = DefaultBezelService()
        XCTAssertNotNil(service.bezelInfo(for: "iPhone", isLandscape: false))
    }

    func testIPadOrientationSelection() {
        let service = DefaultBezelService()
        let portrait = service.bezelInfo(for: "ipad", isLandscape: false)
        let landscape = service.bezelInfo(for: "ipad", isLandscape: true)
        
                XCTAssertTrue(portrait?.url.lastPathComponent.contains("portrait") ?? false)
        
                XCTAssertTrue(landscape?.url.lastPathComponent.contains("landscape") ?? false)
        
            }
        
        
        
                func testDownloadBezel() async throws {
        
        
        
                    let service = DefaultBezelService()
        
        
        
                    let iphoneInfo = service.bezelInfo(for: "iphone", isLandscape: false)!
        
        
        
                    let iphoneURL = try await service.downloadBezelIfNeeded(for: iphoneInfo)
        
        
        
                    XCTAssertTrue(FileManager.default.fileExists(atPath: iphoneURL.path))
        
        
        
            
        
        
        
                    let ipadInfo = service.bezelInfo(for: "ipad", isLandscape: false)!
        
        
        
                    let ipadURL = try await service.downloadBezelIfNeeded(for: ipadInfo)
        
        
        
                    XCTAssertTrue(FileManager.default.fileExists(atPath: ipadURL.path))
        
        
        
                }
        
        
        
            }
        
        
        
            
        
        
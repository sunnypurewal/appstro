import XCTest
@testable import AppstroServices
import AppstroCore

final class PreferenceServiceTests: XCTestCase {
    var tempURL: URL!

    override func setUp() {
        tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testLoadSavePreferences() {
        let service = FilePreferenceService(configURL: tempURL)
        
        // Initial load should be empty
        var prefs = service.loadPreferences()
        XCTAssertNil(prefs.lastUsedPrefix)
        
        // Save prefix
        service.savePrefix("test")
        
        // Load again
        prefs = service.loadPreferences()
        XCTAssertEqual(prefs.lastUsedPrefix, "test")
    }
}

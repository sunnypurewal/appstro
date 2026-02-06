import XCTest
import AppstroCore
import ArgumentParser
@testable import appstro

final class LoginCommandTests: XCTestCase {
    var mockUI: MockUserInterface!
    
    override func setUp() {
        super.setUp()
        mockUI = MockUserInterface()
        Environment.live = Environment(ui: mockUI)
    }
    
    func testLoginCommand() throws {
        var openedURL: URL?
        mockUI.openURLHandler = { url in
            openedURL = url
        }
        
        mockUI.promptHandler = { _, _ in
            return "" // Press Enter
        }
        
        let cmd = try Login.parseAsRoot([])
        try (cmd as! Login).run()
        
        XCTAssertNotNil(openedURL)
        XCTAssertEqual(openedURL?.absoluteString, "https://appstoreconnect.apple.com/access/integrations/api")
    }
}

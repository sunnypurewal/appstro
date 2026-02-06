import XCTest
import ArgumentParser
@testable import appstro

final class CommandTests: XCTestCase {
    func testVersionCommandParsing() throws {
        let command = try Appstro.parseAsRoot(["version"])
        XCTAssertTrue(command is Version)
    }

    func testAppCommandParsing() throws {
        let command = try Appstro.parseAsRoot(["app", "com.example.app"])
        XCTAssertTrue(command is App)
        let app = command as! App
        XCTAssertEqual(app.parameter, "com.example.app")
    }

    func testSubmissionCommandParsing() throws {
        let command = try Appstro.parseAsRoot(["submission", "create", "1.0.1", "--platform", "ios"])
        XCTAssertTrue(command is CreateSubmission)
        let create = command as! CreateSubmission
        XCTAssertEqual(create.version, "1.0.1")
        XCTAssertEqual(create.platform, "ios")
    }

    func testScreenshotsCommandParsing() throws {
        let command = try Appstro.parseAsRoot(["submission", "screenshots", "--device", "ipad"])
        XCTAssertTrue(command is Screenshots)
        let screenshots = command as! Screenshots
        XCTAssertEqual(screenshots.device, "ipad")
    }
}

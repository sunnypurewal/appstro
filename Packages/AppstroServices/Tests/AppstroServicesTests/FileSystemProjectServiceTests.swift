import XCTest
import Foundation
@testable import AppstroServices

final class FileSystemProjectServiceTests: XCTestCase {
	var tempDir: URL!
	var service: FileSystemProjectService!
	
	override func setUp() {
		super.setUp()
		tempDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
		try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
		service = FileSystemProjectService()
	}
	
	override func tearDown() {
		try? FileManager.default.removeItem(at: tempDir)
		super.tearDown()
	}
	
	func testEnsureReleaseDirectoryCreatesGitIgnore() throws {
		let version = "1.0.0"
		_ = try service.ensureReleaseDirectory(at: tempDir, version: version)
		
		let gitignoreURL = tempDir.appendingPathComponent(".gitignore")
		XCTAssertTrue(FileManager.default.fileExists(atPath: gitignoreURL.path))
		
		let content = try String(contentsOf: gitignoreURL, encoding: .utf8)
		XCTAssertTrue(content.contains(".appstro/"))
	}
	
	func testEnsureReleaseDirectoryAppendsToExistingGitIgnore() throws {
		let gitignoreURL = tempDir.appendingPathComponent(".gitignore")
		try "existing_entry\n".write(to: gitignoreURL, atomically: true, encoding: .utf8)
		
		let version = "1.0.0"
		_ = try service.ensureReleaseDirectory(at: tempDir, version: version)
		
		let content = try String(contentsOf: gitignoreURL, encoding: .utf8)
		XCTAssertTrue(content.contains("existing_entry"))
		XCTAssertTrue(content.contains(".appstro/"))
	}

    func testEnsureReleaseDirectoryDoesNotDuplicateGitIgnoreEntry() throws {
        let gitignoreURL = tempDir.appendingPathComponent(".gitignore")
        try ".appstro/\n".write(to: gitignoreURL, atomically: true, encoding: .utf8)
        
        let version = "1.0.0"
        _ = try service.ensureReleaseDirectory(at: tempDir, version: version)
        
        let content = try String(contentsOf: gitignoreURL, encoding: .utf8)
        let count = content.components(separatedBy: ".appstro/").count - 1
        XCTAssertEqual(count, 1)
    }
}
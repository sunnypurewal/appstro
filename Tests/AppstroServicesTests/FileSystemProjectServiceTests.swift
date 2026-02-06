import XCTest
import Foundation
import AppstroCore
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
	
	func testEnsureReleaseDirectoryCreatesGitIgnore() async throws {
		let version = "1.0.0"
		_ = try await service.ensureReleaseDirectory(at: tempDir, version: version)
		
		let gitignoreURL = tempDir.appendingPathComponent(".gitignore")
		XCTAssertTrue(FileManager.default.fileExists(atPath: gitignoreURL.path))
		
		let content = try String(contentsOf: gitignoreURL, encoding: .utf8)
		XCTAssertTrue(content.contains(".appstro/"))
	}
	
	func testEnsureReleaseDirectoryAppendsToExistingGitIgnore() async throws {
		let gitignoreURL = tempDir.appendingPathComponent(".gitignore")
		try "existing_entry\n".write(to: gitignoreURL, atomically: true, encoding: .utf8)
		
		let version = "1.0.0"
		_ = try await service.ensureReleaseDirectory(at: tempDir, version: version)
		
		let content = try String(contentsOf: gitignoreURL, encoding: .utf8)
		XCTAssertTrue(content.contains("existing_entry"))
		XCTAssertTrue(content.contains(".appstro/"))
	}

    func testEnsureReleaseDirectoryDoesNotDuplicateGitIgnoreEntry() async throws {
        let gitignoreURL = tempDir.appendingPathComponent(".gitignore")
        try ".appstro/\n".write(to: gitignoreURL, atomically: true, encoding: .utf8)
        
        let version = "1.0.0"
        _ = try await service.ensureReleaseDirectory(at: tempDir, version: version)
        
        let content = try String(contentsOf: gitignoreURL, encoding: .utf8)
        let count = content.components(separatedBy: ".appstro/").count - 1
        XCTAssertEqual(count, 1)
    }

    func testFindProjectRoot() throws {
        let subDir = tempDir.appendingPathComponent("sub/dir")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try "{}".write(to: tempDir.appendingPathComponent("appstro.json"), atomically: true, encoding: .utf8)
        
        let originalCwd = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(subDir.path)
        defer { FileManager.default.changeCurrentDirectoryPath(originalCwd) }
        
        let root = service.findProjectRoot()
        XCTAssertNotNil(root)
		if let root {
			XCTAssertEqual(root.resolvingSymlinksInPath().standardized.path, tempDir.resolvingSymlinksInPath().standardized.path)
		}
    }

    func testLoadSaveConfig() throws {
        let config = AppstroCore.AppstroConfig(name: "Test", description: "Desc", keywords: ["k1"], bundleIdentifier: "com.test", appPath: ".", teamID: "T1")
        try service.saveConfig(config, at: tempDir)
        
        let loaded = try service.loadConfig(at: tempDir)
        XCTAssertEqual(loaded.name, "Test")
        XCTAssertEqual(loaded.bundleIdentifier, "com.test")
    }
}

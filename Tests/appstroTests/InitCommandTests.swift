import XCTest
import AppstroCore
import ArgumentParser
import PathKit
@testable import appstro

final class InitCommandTests: XCTestCase {
    var mockProject: MockProjectService!
    var mockUI: MockUserInterface!
    var tempDir: Path!
    
    override func setUp() {
        super.setUp()
        mockProject = MockProjectService()
        mockUI = MockUserInterface()
        tempDir = Path("/tmp/appstro_test_\(UUID().uuidString)")
        try? tempDir.mkpath()
        
        Environment.live = Environment(
            project: mockProject,
            ui: mockUI
        )
    }
    
    override func tearDown() {
        try? tempDir.delete()
        super.tearDown()
    }
    
    func testInitNewProject() async throws {
        var gitInitialized = false
        mockProject.initializeGitHandler = { _ in
            gitInitialized = true
        }

        mockUI.promptHandler = { text, defaultValue in
            if text == "app name" { return "TestApp" }
            if text == "Is this OK?" { return "yes" }
            return defaultValue ?? ""
        }
        
        mockProject.containsXcodeProjectHandler = { _ in nil }
        mockProject.getBundleIdentifierHandler = { _ in nil }
        
        var cmd = Init()
        cmd.path = tempDir.string
        try await cmd.run()
        
        XCTAssertTrue((tempDir + "appstro.json").exists)
        XCTAssertTrue((tempDir + "Sources/App.swift").exists)
        XCTAssertTrue(gitInitialized)
    }

    func testInitExistingProject() async throws {
        mockUI.promptHandler = { text, defaultValue in
            if text == "app name" { return "TestApp" }
            if text == "Is this OK?" { return "yes" }
            return defaultValue ?? ""
        }
        
        mockProject.containsXcodeProjectHandler = { _ in "TestApp" }
        mockProject.getBundleIdentifierHandler = { _ in "com.test.id" }
        
        var cmd = Init()
        cmd.path = tempDir.string
        try await cmd.run()
        
        XCTAssertTrue((tempDir + "appstro.json").exists)
        XCTAssertFalse((tempDir + "Sources/App.swift").exists) // Should not create sources if project exists
    }

    func testInitAbortAtConfirmation() async throws {
        mockUI.promptHandler = { text, defaultValue in
            if text == "Is this OK?" { return "no" }
            return defaultValue ?? ""
        }
        
        var cmd = Init()
        cmd.path = tempDir.string
        try await cmd.run()
        
        XCTAssertFalse((tempDir + "appstro.json").exists)
    }
}

import XCTest
@testable import AppstroAI
import AppstroCore

final class QueryInterpreterTests: XCTestCase {
    func testInterpretBundleId() {
        let interpreter = DefaultAppQueryInterpreter()
        let query = interpreter.interpret("com.example.app")
        if case let .bundleId(id) = query.type {
            XCTAssertEqual(id, "com.example.app")
        } else {
            XCTFail("Expected bundleId")
        }
    }

    func testInterpretName() {
        let interpreter = DefaultAppQueryInterpreter()
        let query = interpreter.interpret("My Great App")
        if case let .name(name) = query.type {
            XCTAssertEqual(name, "My Great App")
        } else {
            XCTFail("Expected name")
        }
    }
}

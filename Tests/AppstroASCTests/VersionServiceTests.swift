import XCTest
import AppStoreConnect_Swift_SDK
import AppstroCore
@testable import AppstroASC

final class VersionServiceTests: XCTestCase {
    var mock: MockRequestProvider!
    var service: ASCVersionService!

    override func setUp() {
        mock = MockRequestProvider()
        service = ASCVersionService(provider: mock)
    }

    func testFindDraftVersion() async throws {
        let version = AppStoreVersion(
            type: .appStoreVersions,
            id: "v1",
            attributes: .init(versionString: "1.0.0", appStoreState: .prepareForSubmission)
        )
        let response = AppStoreVersionsResponse(data: [version], links: .init(this: ""))
        mock.responses = [response]

        let draft = try await service.findDraftVersion(for: "app1")
        XCTAssertNotNil(draft)
        XCTAssertEqual(draft?.version, "1.0.0")
        XCTAssertEqual(draft?.state, .prepareForSubmission)
    }

    func testFetchBuilds() async throws {
        let build = AppStoreConnect_Swift_SDK.Build(
            type: .builds,
            id: "b1",
            attributes: .init(version: "123", processingState: .valid)
        )
        let response = BuildsResponse(data: [build], links: .init(this: ""))
        mock.responses = [response]

        let builds = try await service.fetchBuilds(appId: "app1")
        XCTAssertEqual(builds.count, 1)
        XCTAssertEqual(builds[0].id, "b1")
        XCTAssertEqual(builds[0].version, "123")
        XCTAssertEqual(builds[0].processingState, .valid)
    }
}
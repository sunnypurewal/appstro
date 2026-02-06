import XCTest
import AppStoreConnect_Swift_SDK
import AppstroCore
@testable import AppstroASC

final class MetadataServiceTests: XCTestCase {
    var mock: MockRequestProvider!
    var service: ASCMetadataService!

    override func setUp() {
        mock = MockRequestProvider()
        service = ASCMetadataService(provider: mock)
    }

    func testFetchLocalization() async throws {
        let loc = AppStoreVersionLocalization(
            type: .appStoreVersionLocalizations,
            id: "loc1",
            attributes: .init(description: "Desc", keywords: "Keys")
        )
        let response = AppStoreVersionLocalizationsResponse(data: [loc], links: .init(this: ""))
        mock.responses = [response]

        let result = try await service.fetchLocalization(versionId: "v1")
        XCTAssertEqual(result.description, "Desc")
        XCTAssertEqual(result.keywords, "Keys")
    }

    func testUpdateVersionAttributes() async throws {
        let version = AppStoreVersion(type: .appStoreVersions, id: "v1")
        let response = AppStoreVersionResponse(data: version, links: .init(this: ""))
        mock.responses = [response]

        try await service.updateVersionAttributes(versionId: "v1", copyright: "2024")
        XCTAssertEqual(mock.callCount, 1)
    }
}
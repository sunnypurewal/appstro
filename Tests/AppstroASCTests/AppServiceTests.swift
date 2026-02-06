import XCTest
import AppStoreConnect_Swift_SDK
import AppstroCore
@testable import AppstroASC

final class AppServiceTests: XCTestCase {
    var mock: MockRequestProvider!
    var service: ASCAppService!

    override func setUp() {
        mock = MockRequestProvider()
        service = ASCAppService(provider: mock)
    }

    func testListApps() async throws {
        let app = AppStoreConnect_Swift_SDK.App(
            type: .apps,
            id: "1",
            attributes: .init(name: "Test App", bundleID: "com.test")
        )
        let response = AppsResponse(data: [app], links: .init(this: ""))
        mock.responses = [response]

        let apps = try await service.listApps()
        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps[0].name, "Test App")
        XCTAssertEqual(apps[0].bundleId, "com.test")
    }

    func testFetchAppDetailsByName() async throws {
        let app = AppStoreConnect_Swift_SDK.App(
            type: .apps,
            id: "1",
            attributes: .init(name: "Test App", bundleID: "com.test")
        )
        let response = AppsResponse(data: [app], links: .init(this: ""))
        mock.responses = [response]

        let details = try await service.fetchAppDetails(query: .init(type: .name("Test App")))
        XCTAssertNotNil(details)
        XCTAssertEqual(details?.name, "Test App")
    }

    func testFetchAppDetailsByBundleId() async throws {
        let app = AppStoreConnect_Swift_SDK.App(
            type: .apps,
            id: "1",
            attributes: .init(name: "Test App", bundleID: "com.test")
        )
        let response = AppsResponse(data: [app], links: .init(this: ""))
        mock.responses = [response]

        let details = try await service.fetchAppDetails(query: .init(type: .bundleId("com.test")))
        XCTAssertNotNil(details)
        XCTAssertEqual(details?.bundleId, "com.test")
    }
}

import XCTest
import AppStoreConnect_Swift_SDK
import AppstroCore
@testable import AppstroASC

final class PricingServiceTests: XCTestCase {
    var mock: MockRequestProvider!
    var service: ASCPricingService!

    override func setUp() {
        mock = MockRequestProvider()
        service = ASCPricingService(provider: mock)
    }

    func testFetchAppPricePoints() async throws {
        let point = AppStoreConnect_Swift_SDK.AppPricePointV3(
            type: .appPricePoints,
            id: "p1",
            attributes: .init(customerPrice: "0.99")
        )
        let response = AppPricePointsV3Response(data: [point], links: .init(this: ""))
        mock.responses = [response]

        let points = try await service.fetchAppPricePoints(appId: "app1")
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0], "0.99")
    }
}

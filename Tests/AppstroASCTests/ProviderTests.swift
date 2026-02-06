import XCTest
import AppStoreConnect_Swift_SDK
@testable import AppstroASC

final class ProviderTests: XCTestCase {
    func testErrorMapping() async {
        let mock = MockRequestProvider()
        let provider = AppStoreConnectProvider(requestProvider: mock)
        
        let genericError = NSError(domain: "test", code: 123, userInfo: nil)
        mock.error = genericError
        
        let endpoint = Request<Void>(path: "/test", method: "GET", id: "test")
        do {
            try await provider.requestProvider.request(endpoint)
            XCTFail("Should have thrown")
        } catch {
            XCTAssertEqual((error as NSError).domain, "test")
        }
    }
}
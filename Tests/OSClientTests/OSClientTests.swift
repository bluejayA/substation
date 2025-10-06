import XCTest
@testable import OSClient

final class OSClientTests: XCTestCase {
    func testConfigInit() throws {
        let url = URL(string: "https://example.com/v3")!
        let config = OpenStackConfig(authURL: url, region: "RegionOne")
        XCTAssertEqual(config.authURL, url)
        XCTAssertEqual(config.region, "RegionOne")
    }
}

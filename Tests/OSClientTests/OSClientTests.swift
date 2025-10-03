import XCTest
@testable import OSClient

final class OSClientTests: XCTestCase {
    func testConfigInit() throws {
        let url = URL(string: "https://example.com/v3")!
        let config = OTConfig(authURL: url, region: "RegionOne", projectName: "demo", projectDomain: "Default")
        XCTAssertEqual(config.authURL, url)
        XCTAssertEqual(config.region, "RegionOne")
        XCTAssertEqual(config.projectName, "demo")
    }

    func testClientStoresProject() {
        let client = OSClient(token: "t", catalog: [], region: "RegionOne", project: "demo", preferredInterface: "public")
        XCTAssertEqual(client.project, "demo")
    }
}

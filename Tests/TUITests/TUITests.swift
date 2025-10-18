import XCTest
@testable import Substation

final class TUITests: XCTestCase {
    func testFilterLinesMatchesQuery() {
        let lines = ["alpha", "beta", "gamma"]
        let filtered = FilterUtils.filterLines(lines, query: "ph")
        XCTAssertEqual(filtered, ["alpha"])
    }

    func testFilterLinesNilReturnsAll() {
        let lines = ["alpha", "beta"]
        let filtered = FilterUtils.filterLines(lines, query: nil)
        XCTAssertEqual(filtered, lines)
    }
}

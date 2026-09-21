import XCTest
@testable import CapacitorAppleMapsPlugin

// MARK: - Geocoding address formatting
final class GeocodeTests: XCTestCase {

    /// The postal formatter writes one line per address row; a heading wants one line.
    func testSingleLineAddressJoinsRows() {
        XCTAssertEqual(
            singleLineAddress("1 Main St\nBoston MA 02110\nUnited States"),
            "1 Main St, Boston MA 02110, United States"
        )
    }

    func testSingleLineAddressDropsBlankRows() {
        XCTAssertEqual(singleLineAddress("\n Boston MA \n\nUnited States\n"), "Boston MA, United States")
        XCTAssertEqual(singleLineAddress(""), "")
    }

    func testJoinedAddressPartsSkipsMissingAndEmpty() {
        XCTAssertEqual(joinedAddressParts([nil, "Boston", "", "MA", "  "]), "Boston, MA")
    }

    /// A town's placemark is named after the town, which must not print twice.
    func testJoinedAddressPartsSkipsImmediateRepeats() {
        XCTAssertEqual(joinedAddressParts(["Boston", "Boston", "MA"]), "Boston, MA")
    }

    func testJoinedAddressPartsNilWhenNothingUsable() {
        XCTAssertNil(joinedAddressParts([nil, "", " "]))
    }
}

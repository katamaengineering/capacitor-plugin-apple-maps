import XCTest
@testable import CapacitorAppleMapsPlugin

class CapacitorAppleMapsTests: XCTestCase {
    /// The zoom <-> longitude-delta conversion should round-trip for a fixed
    /// viewport width across the useful zoom range.
    func testZoomRoundTrip() {
        let width = 390.0 // typical iPhone point width
        for zoom in stride(from: 3.0, through: 18.0, by: 1.0) {
            let delta = zoomToLongitudeDelta(zoom, widthPoints: width)
            let recovered = longitudeDeltaToZoom(delta, widthPoints: width)
            XCTAssertEqual(zoom, recovered, accuracy: 0.0001, "zoom \(zoom) did not round-trip")
        }
    }

    /// A larger zoom must produce a narrower longitude span.
    func testHigherZoomIsNarrower() {
        let width = 390.0
        XCTAssertGreaterThan(
            zoomToLongitudeDelta(5, widthPoints: width),
            zoomToLongitudeDelta(12, widthPoints: width)
        )
    }
}

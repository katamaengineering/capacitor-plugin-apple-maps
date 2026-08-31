import XCTest
import MapKit
import Capacitor
@testable import CapacitorAppleMapsPlugin

class CapacitorAppleMapsTests: XCTestCase {

    // MARK: - Zoom <-> region conversion

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

    /// A zero/invalid viewport width must fall back rather than divide by zero.
    func testZoomToDeltaHandlesZeroWidth() {
        let delta = zoomToLongitudeDelta(10, widthPoints: 0)
        XCTAssertTrue(delta.isFinite)
        XCTAssertGreaterThan(delta, 0)
    }

    /// A zero span must not produce a non-finite zoom.
    func testLongitudeDeltaToZoomHandlesZeroDelta() {
        let zoom = longitudeDeltaToZoom(0, widthPoints: 390)
        XCTAssertTrue(zoom.isFinite)
    }

    // MARK: - Region corners (visible bounds math)

    func testRegionCorners() {
        let center = CLLocationCoordinate2D(latitude: 42.0, longitude: -71.0)
        let span = MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 4.0)
        let corners = regionCorners(center: center, span: span)

        XCTAssertEqual(corners.southwest.latitude, 41.0, accuracy: 1e-9)
        XCTAssertEqual(corners.southwest.longitude, -73.0, accuracy: 1e-9)
        XCTAssertEqual(corners.northeast.latitude, 43.0, accuracy: 1e-9)
        XCTAssertEqual(corners.northeast.longitude, -69.0, accuracy: 1e-9)
    }

    // MARK: - Config parsing

    func testConfigParsesCenterAndZoom() throws {
        let obj: JSObject = [
            "center": ["lat": 42.36, "lng": -71.06] as JSObject,
            "zoom": 11.0,
            "minZoom": 7.0
        ]
        let config = try AppleMapConfig(fromJSObject: obj)
        XCTAssertEqual(config.center.latitude, 42.36, accuracy: 1e-9)
        XCTAssertEqual(config.center.longitude, -71.06, accuracy: 1e-9)
        XCTAssertEqual(config.zoom, 11.0)
        XCTAssertEqual(config.minZoom, 7.0)
    }

    func testConfigDefaultsZoomWhenMissing() throws {
        let obj: JSObject = ["center": ["lat": 0.0, "lng": 0.0] as JSObject]
        let config = try AppleMapConfig(fromJSObject: obj)
        XCTAssertEqual(config.zoom, 12.0)
        XCTAssertNil(config.minZoom)
    }

    func testConfigThrowsWithoutCenter() {
        let obj: JSObject = ["zoom": 11.0]
        XCTAssertThrowsError(try AppleMapConfig(fromJSObject: obj))
    }

    // MARK: - CGRect parsing

    func testCGRectFromJSObject() {
        let obj: JSObject = ["x": 1.0, "y": 2.0, "width": 3.0, "height": 4.0]
        let rect = CGRect.fromJSObject(obj)
        XCTAssertEqual(rect.origin.x, 1.0)
        XCTAssertEqual(rect.origin.y, 2.0)
        XCTAssertEqual(rect.size.width, 3.0)
        XCTAssertEqual(rect.size.height, 4.0)
    }

    func testCGRectFromJSObjectDefaultsToZero() {
        let rect = CGRect.fromJSObject([:])
        XCTAssertEqual(rect, .zero)
    }

    // MARK: - Search distance filter

    func testWithinDistanceNoFilterWhenLimitMissing() {
        let boston = CLLocation(latitude: 42.36, longitude: -71.06)
        let saoPaulo = CLLocationCoordinate2D(latitude: -23.55, longitude: -46.63)
        // No/zero limit means "keep everything".
        XCTAssertTrue(withinDistance(maxKm: nil, from: boston, to: saoPaulo))
        XCTAssertTrue(withinDistance(maxKm: 0, from: boston, to: saoPaulo))
        // No center means "keep everything".
        XCTAssertTrue(withinDistance(maxKm: 800, from: nil, to: saoPaulo))
    }

    func testWithinDistanceKeepsNearbyDropsFar() {
        let boston = CLLocation(latitude: 42.36, longitude: -71.06)
        let portland = CLLocationCoordinate2D(latitude: 43.66, longitude: -70.26) // ~150 km
        let saoPaulo = CLLocationCoordinate2D(latitude: -23.55, longitude: -46.63) // ~7000 km
        XCTAssertTrue(withinDistance(maxKm: 800, from: boston, to: portland))
        XCTAssertFalse(withinDistance(maxKm: 800, from: boston, to: saoPaulo))
    }
}

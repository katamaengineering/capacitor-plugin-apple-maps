import Foundation
import MapKit
import Capacitor
import WebKit

// MARK: - Errors

enum AppleMapsError: Error, LocalizedError {
    case invalidArguments(String)

    var errorDescription: String? {
        switch self {
        case .invalidArguments(let message):
            return message
        }
    }
}

// MARK: - Zoom <-> region conversion
//
// MapKit has no notion of a Google-style integer zoom; it works in region
// spans. These helpers convert between the two using the web-mercator tile
// relationship: the whole world (360°) is `256 * 2^zoom` points wide, so a
// viewport `widthPoints` points wide spans `360 * widthPoints / (256 * 2^zoom)`
// degrees of longitude. The round trip is approximate - MapKit adjusts spans to
// the view's aspect ratio - which is fine for the host app's radius estimates.

func zoomToLongitudeDelta(_ zoom: Double, widthPoints: Double) -> Double {
    let width = widthPoints > 0 ? widthPoints : 256.0
    return 360.0 * width / (256.0 * pow(2.0, zoom))
}

func longitudeDeltaToZoom(_ delta: Double, widthPoints: Double) -> Double {
    let width = widthPoints > 0 ? widthPoints : 256.0
    let safeDelta = delta > 0 ? delta : 0.0001
    return log2(360.0 * width / (256.0 * safeDelta))
}

/// Clamps a Google-style zoom to an optional `[minZoom, maxZoom]` range. A nil
/// bound means unbounded on that side; if `minZoom > maxZoom` the ceiling wins.
/// Pure so the clamp behavior can be unit-tested without an `MKMapView`.
func clampZoom(_ zoom: Double, minZoom: Double?, maxZoom: Double?) -> Double {
    var result = max(zoom, minZoom ?? -Double.greatestFiniteMagnitude)
    result = min(result, maxZoom ?? Double.greatestFiniteMagnitude)
    return result
}

/// The smallest `MKMapRect` containing both corners, regardless of their relative
/// orientation (latitude grows north but `MKMapPoint.y` grows south). Pure so the
/// `fitBounds` framing math can be unit-tested without an `MKMapView`.
func boundingMapRect(southwest: CLLocationCoordinate2D, northeast: CLLocationCoordinate2D) -> MKMapRect {
    let swPoint = MKMapPoint(southwest)
    let nePoint = MKMapPoint(northeast)
    return MKMapRect(
        x: min(swPoint.x, nePoint.x),
        y: min(swPoint.y, nePoint.y),
        width: abs(swPoint.x - nePoint.x),
        height: abs(swPoint.y - nePoint.y)
    )
}

/// The corner coordinates of a region, used to report the visible bounds to JS.
/// Pure function so it can be unit-tested without an `MKMapView`.
func regionCorners(center: CLLocationCoordinate2D, span: MKCoordinateSpan)
-> (southwest: CLLocationCoordinate2D, northeast: CLLocationCoordinate2D) {
    let southwest = CLLocationCoordinate2D(
        latitude: center.latitude - span.latitudeDelta / 2,
        longitude: center.longitude - span.longitudeDelta / 2
    )
    let northeast = CLLocationCoordinate2D(
        latitude: center.latitude + span.latitudeDelta / 2,
        longitude: center.longitude + span.longitudeDelta / 2
    )
    return (southwest, northeast)
}

// MARK: - Annotation

/// A map pin carrying a stable id echoed back to JS on tap. The id is generated
/// unless the caller supplied one in the marker payload.
class AppleMapMarker: MKPointAnnotation {
    var markerId: String = UUID().uuidString
    var iconUrl: String?
    var iconSize: CGSize?
}

/// Stroke/fill styling for an overlay, resolved from the JS payload and looked
/// up by the map's `rendererFor` delegate when MapKit asks how to draw it.
struct OverlayStyle {
    var strokeColor: UIColor
    var lineWidth: CGFloat
    var fillColor: UIColor?
}

// MARK: - Config

struct AppleMapConfig {
    let center: CLLocationCoordinate2D
    let zoom: Double
    let minZoom: Double?
    let maxZoom: Double?
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let clustering: Bool
    let mapType: String
    let showInfoWindows: Bool

    init(fromJSObject obj: JSObject) throws {
        guard let centerObj = obj["center"] as? JSObject,
              let lat = centerObj["lat"] as? Double,
              let lng = centerObj["lng"] as? Double else {
            throw AppleMapsError.invalidArguments("config.center is missing or malformed")
        }
        self.center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        self.zoom = obj["zoom"] as? Double ?? 12
        self.minZoom = obj["minZoom"] as? Double
        self.maxZoom = obj["maxZoom"] as? Double
        self.width = obj["width"] as? Double ?? 0
        self.height = obj["height"] as? Double ?? 0
        self.x = obj["x"] as? Double ?? 0
        self.y = obj["y"] as? Double ?? 0
        self.clustering = obj["clustering"] as? Bool ?? false
        self.mapType = obj["mapType"] as? String ?? "standard"
        self.showInfoWindows = obj["showInfoWindows"] as? Bool ?? false
    }
}

// MARK: - Map

/// Owns one native `MKMapView` and mounts it into the WKWebView's view tree at
/// the bound element's location, mirroring the compositing approach of
/// `@capacitor/google-maps`.
public class Map: NSObject, UIGestureRecognizerDelegate {
    static let mapTag = 99999

    let id: String
    var config: AppleMapConfig
    let mapView: MKMapView

    var markers: [String: AppleMapMarker] = [:]
    /// Overlays keyed by the id handed back to JS, for removal.
    var overlays: [String: MKOverlay] = [:]
    /// Overlay styling keyed by the overlay instance, read back in `rendererFor`.
    var overlayStyles: [ObjectIdentifier: OverlayStyle] = [:]
    private(set) var clusteringEnabled = false

    /// Guards against a feedback loop when we programmatically clamp the region
    /// back to the minimum zoom inside `regionDidChange`.
    var isAdjustingRegion = false

    weak var delegate: CapacitorAppleMapsPlugin?
    var targetView: UIView?
    /// Decoded marker icons keyed by their url/asset string. `NSCache` bounds the
    /// footprint and evicts under memory pressure, unlike a plain dictionary that
    /// would grow without limit as icons come and go. Read/written in MarkerIcons.
    let iconCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        return cache
    }()
    /// Remote icon urls with a download in flight, so a re-render (e.g. a
    /// clustering toggle re-adding every annotation) doesn't start a duplicate.
    var inFlightIconURLs: Set<String> = []
    /// Remote icon urls that returned a response but no usable image - a permanent
    /// miss we must not retry on every re-render (a transport error is left out so
    /// a later render can retry it).
    var failedIconURLs: Set<String> = []

    init(id: String, config: AppleMapConfig, delegate: CapacitorAppleMapsPlugin) {
        self.id = id
        self.config = config
        self.mapView = MKMapView()
        self.delegate = delegate
        super.init()
        // Start clustered when the caller asked for it, so markers added later
        // cluster on their first render instead of flashing as individual pins.
        self.clusteringEnabled = config.clustering
        self.render()
    }

    private func render() {
        DispatchQueue.main.async {
            self.mapView.delegate = self.delegate
            self.mapView.showsUserLocation = false
            self.mapView.mapType = Map.mapType(from: self.config.mapType)
            self.mapView.frame = CGRect(x: self.config.x, y: self.config.y, width: self.config.width, height: self.config.height)
            self.setCameraInternal(coordinate: self.config.center, zoom: self.config.zoom, animate: false)

            // Emit onMapClick for taps that don't land on a marker. cancelsTouchesInView
            // stays false and the delegate allows simultaneous recognition so this
            // never swallows MapKit's own pan/zoom or marker-selection gestures.
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.handleMapTap(_:)))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            self.mapView.addGestureRecognizer(tap)

            // Emit onMapLongClick for a long-press that doesn't land on a marker.
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(self.handleMapLongPress(_:)))
            longPress.cancelsTouchesInView = false
            longPress.delegate = self
            self.mapView.addGestureRecognizer(longPress)

            self.targetView = self.getTargetContainer(refWidth: self.config.width, refHeight: self.config.height)
            if let target = self.targetView {
                target.tag = Map.mapTag
                target.removeAllSubview()
                self.mapView.frame = target.bounds
                self.mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                target.addSubview(self.mapView)
            }

            self.delegate?.notifyListeners("onMapReady", data: ["mapId": self.id])
        }
    }

    func destroy() {
        DispatchQueue.main.async {
            self.mapView.removeFromSuperview()
            self.mapView.delegate = nil
            self.targetView?.tag = 0
        }
    }

    // MARK: Camera

    /// Must be called on the main thread.
    func setCameraInternal(coordinate: CLLocationCoordinate2D?, zoom: Double?, animate: Bool) {
        let center = coordinate ?? mapView.centerCoordinate

        guard let zoom = zoom else {
            mapView.setCenter(center, animated: animate)
            return
        }

        // Enforce the zoom range: a smaller zoom means a wider span (minZoom is the
        // zoom-out floor), a larger zoom a tighter one (maxZoom is the zoom-in ceiling).
        let clampedZoom = clampZoom(zoom, minZoom: config.minZoom, maxZoom: config.maxZoom)

        let width = Double(mapView.bounds.width > 0 ? mapView.bounds.width : UIScreen.main.bounds.width)
        let height = Double(mapView.bounds.height > 0 ? mapView.bounds.height : UIScreen.main.bounds.height)
        let lonDelta = min(zoomToLongitudeDelta(clampedZoom, widthPoints: width), 360.0)
        let latDelta = min(lonDelta * (height / max(width, 1)), 180.0)
        let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        let region = mapView.regionThatFits(MKCoordinateRegion(center: center, span: span))
        mapView.setRegion(region, animated: animate)
    }

    /// Must be called on the main thread.
    func currentZoom() -> Double {
        let width = Double(mapView.bounds.width > 0 ? mapView.bounds.width : UIScreen.main.bounds.width)
        return longitudeDeltaToZoom(mapView.region.span.longitudeDelta, widthPoints: width)
    }

    /// Must be called on the main thread. Shape matches `LatLngBounds` in JS.
    func boundsPayload() -> PluginCallResultData {
        let region = mapView.region
        let corners = regionCorners(center: region.center, span: region.span)
        return [
            "center": ["lat": region.center.latitude, "lng": region.center.longitude],
            "southwest": ["lat": corners.southwest.latitude, "lng": corners.southwest.longitude],
            "northeast": ["lat": corners.northeast.latitude, "lng": corners.northeast.longitude]
        ]
    }

    /// Must be called on the main thread. Shape matches `CameraPosition` in JS.
    func cameraPayload() -> PluginCallResultData {
        let center = mapView.centerCoordinate
        return [
            "latitude": center.latitude,
            "longitude": center.longitude,
            "zoom": currentZoom(),
            "bounds": boundsPayload()
        ]
    }

    /// Frame `southwest`..`northeast` in the viewport, inset by `padding` points.
    func fitBounds(southwest: CLLocationCoordinate2D, northeast: CLLocationCoordinate2D, padding: Double, animate: Bool) {
        let rect = boundingMapRect(southwest: southwest, northeast: northeast)
        DispatchQueue.main.sync {
            let inset = UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
            self.mapView.setVisibleMapRect(rect, edgePadding: inset, animated: animate)
        }
    }

    // MARK: Markers

    func addMarkers(_ markerObjs: [JSObject]) -> [String] {
        var ids: [String] = []
        DispatchQueue.main.sync {
            var toAdd: [AppleMapMarker] = []
            for obj in markerObjs {
                guard let marker = Map.makeMarker(from: obj) else { continue }
                self.markers[marker.markerId] = marker
                toAdd.append(marker)
                ids.append(marker.markerId)
            }
            self.mapView.addAnnotations(toAdd)
        }
        return ids
    }

    /// Builds an annotation from a marker payload, or nil if the coordinate is
    /// missing/malformed. Pure (no `MKMapView`), so it can be unit-tested.
    static func makeMarker(from obj: JSObject) -> AppleMapMarker? {
        guard let coordObj = obj["coordinate"] as? JSObject,
              let lat = coordObj["lat"] as? Double,
              let lng = coordObj["lng"] as? Double else { return nil }
        let marker = AppleMapMarker()
        if let customId = obj["markerId"] as? String, !customId.isEmpty {
            marker.markerId = customId
        }
        marker.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        marker.title = obj["title"] as? String
        marker.subtitle = obj["snippet"] as? String
        marker.iconUrl = obj["iconUrl"] as? String
        if let sizeObj = obj["iconSize"] as? JSObject,
           let width = sizeObj["width"] as? Double,
           let height = sizeObj["height"] as? Double {
            marker.iconSize = CGSize(width: width, height: height)
        }
        return marker
    }

    func removeMarkers(_ ids: [String]) {
        DispatchQueue.main.sync {
            var toRemove: [AppleMapMarker] = []
            for id in ids {
                if let marker = self.markers[id] {
                    toRemove.append(marker)
                    self.markers.removeValue(forKey: id)
                }
            }
            self.mapView.removeAnnotations(toRemove)
        }
    }

    /// Apply partial changes to existing markers. A moved marker animates to its
    /// new coordinate; an icon change re-adds the annotation so `viewFor` reruns.
    func updateMarkers(_ objs: [JSObject]) {
        DispatchQueue.main.sync {
            var toRefresh: [AppleMapMarker] = []
            for obj in objs {
                guard let markerId = obj["markerId"] as? String,
                      let marker = self.markers[markerId] else { continue }

                if let coordObj = obj["coordinate"] as? JSObject,
                   let lat = coordObj["lat"] as? Double,
                   let lng = coordObj["lng"] as? Double {
                    UIView.animate(withDuration: 0.25) {
                        marker.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                    }
                }
                if obj.keys.contains("title") {
                    marker.title = obj["title"] as? String
                }
                if obj.keys.contains("snippet") {
                    marker.subtitle = obj["snippet"] as? String
                }
                var iconChanged = false
                if obj.keys.contains("iconUrl") {
                    marker.iconUrl = obj["iconUrl"] as? String
                    iconChanged = true
                }
                if let sizeObj = obj["iconSize"] as? JSObject,
                   let width = sizeObj["width"] as? Double,
                   let height = sizeObj["height"] as? Double {
                    marker.iconSize = CGSize(width: width, height: height)
                    iconChanged = true
                }
                if iconChanged { toRefresh.append(marker) }
            }
            if !toRefresh.isEmpty {
                self.mapView.removeAnnotations(toRefresh)
                self.mapView.addAnnotations(toRefresh)
            }
        }
    }

    func enableClustering() {
        DispatchQueue.main.sync {
            guard !self.clusteringEnabled else { return }
            self.clusteringEnabled = true
            self.refreshAnnotations()
        }
    }

    func disableClustering() {
        DispatchQueue.main.sync {
            guard self.clusteringEnabled else { return }
            self.clusteringEnabled = false
            self.refreshAnnotations()
        }
    }

    /// Re-add every annotation so `viewFor` reruns and the clustering identifier
    /// is applied or cleared. Must be called on the main thread.
    private func refreshAnnotations() {
        let all = Array(self.markers.values)
        self.mapView.removeAnnotations(all)
        self.mapView.addAnnotations(all)
    }

}

// MARK: - WKWebView touch routing
//
// Routes touches that land on a WKChildScrollView down to the native map view
// mounted inside it. Ported from `@capacitor/google-maps`.
extension WKWebView {
    override open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        var hitView = super.hitTest(point, with: event)
        if let childScrollClass = NSClassFromString("WKChildScrollView"),
           let candidate = hitView, candidate.isKind(of: childScrollClass) {
            for item in candidate.subviews.reversed() {
                let converted = item.convert(point, from: self)
                if let inner = item.hitTest(converted, with: event) {
                    hitView = inner
                    break
                }
            }
        }
        return hitView
    }
}

// MARK: - View tree helpers (ported from @capacitor/google-maps)

extension UIView {
    private static var allSubviews: [UIView] = []

    private func viewArray(root: UIView) -> [UIView] {
        var index = root.tag
        for view in root.subviews {
            if view.tag == Map.mapTag { continue }
            view.tag = index
            UIView.allSubviews.append(view)
            _ = viewArray(root: view)
            index += 1
        }
        return UIView.allSubviews
    }

    func getAllSubViews() -> [UIView] {
        UIView.allSubviews = []
        return viewArray(root: self).reversed()
    }

    func removeAllSubview() {
        subviews.forEach { $0.removeFromSuperview() }
    }
}

extension CGRect {
    static func fromJSObject(_ obj: JSObject) -> CGRect {
        let x = obj["x"] as? Double ?? 0
        let y = obj["y"] as? Double ?? 0
        let width = obj["width"] as? Double ?? 0
        let height = obj["height"] as? Double ?? 0
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

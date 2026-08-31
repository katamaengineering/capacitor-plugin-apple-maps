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

/// A map pin carrying a stable id echoed back to JS on tap.
class AppleMapMarker: MKPointAnnotation {
    let markerId: String = UUID().uuidString
    var iconUrl: String?
    var iconSize: CGSize?
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
    }
}

// MARK: - Map

/// Owns one native `MKMapView` and mounts it into the WKWebView's view tree at
/// the bound element's location, mirroring the compositing approach of
/// `@capacitor/google-maps`.
public class Map: NSObject {
    static let mapTag = 99999

    let id: String
    var config: AppleMapConfig
    let mapView: MKMapView

    var markers: [String: AppleMapMarker] = [:]
    private(set) var clusteringEnabled = false

    /// Guards against a feedback loop when we programmatically clamp the region
    /// back to the minimum zoom inside `regionDidChange`.
    var isAdjustingRegion = false

    private weak var delegate: CapacitorAppleMapsPlugin?
    private var targetView: UIView?
    private var iconCache: [String: UIImage] = [:]

    init(id: String, config: AppleMapConfig, delegate: CapacitorAppleMapsPlugin) {
        self.id = id
        self.config = config
        self.mapView = MKMapView()
        self.delegate = delegate
        super.init()
        self.render()
    }

    private func render() {
        DispatchQueue.main.async {
            self.mapView.delegate = self.delegate
            self.mapView.showsUserLocation = false
            self.mapView.frame = CGRect(x: self.config.x, y: self.config.y, width: self.config.width, height: self.config.height)
            self.setCameraInternal(coordinate: self.config.center, zoom: self.config.zoom, animate: false)

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

        // Enforce the zoom-out floor: a smaller zoom means a wider span.
        let clampedZoom = max(zoom, config.minZoom ?? -Double.greatestFiniteMagnitude)

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

    // MARK: Markers

    func addMarkers(_ markerObjs: [JSObject]) -> [String] {
        var ids: [String] = []
        DispatchQueue.main.sync {
            var toAdd: [AppleMapMarker] = []
            for obj in markerObjs {
                guard let coordObj = obj["coordinate"] as? JSObject,
                      let lat = coordObj["lat"] as? Double,
                      let lng = coordObj["lng"] as? Double else { continue }
                let marker = AppleMapMarker()
                marker.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
                marker.title = obj["title"] as? String
                marker.iconUrl = obj["iconUrl"] as? String
                if let sizeObj = obj["iconSize"] as? JSObject,
                   let width = sizeObj["width"] as? Double,
                   let height = sizeObj["height"] as? Double {
                    marker.iconSize = CGSize(width: width, height: height)
                }
                self.markers[marker.markerId] = marker
                toAdd.append(marker)
                ids.append(marker.markerId)
            }
            self.mapView.addAnnotations(toAdd)
        }
        return ids
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

    // MARK: Icons

    /// Resolves a marker icon. Returns nil synchronously for `https:` URLs and
    /// sets the image on the live annotation view once the download finishes.
    /// Must be called on the main thread.
    func annotationImage(for marker: AppleMapMarker, in mapView: MKMapView) -> UIImage? {
        guard let iconUrl = marker.iconUrl else { return nil }

        if let cached = iconCache[iconUrl] {
            return resize(cached, marker.iconSize)
        }

        if iconUrl.hasPrefix("data:") {
            if let commaIndex = iconUrl.firstIndex(of: ","),
               let data = Data(base64Encoded: String(iconUrl[iconUrl.index(after: commaIndex)...])),
               let image = UIImage(data: data) {
                iconCache[iconUrl] = image
                return resize(image, marker.iconSize)
            }
            return nil
        }

        if iconUrl.hasPrefix("http") {
            if let url = URL(string: iconUrl) {
                URLSession.shared.dataTask(with: url) { [weak self, weak mapView] data, _, _ in
                    guard let self = self, let data = data, let image = UIImage(data: data) else { return }
                    DispatchQueue.main.async {
                        self.iconCache[iconUrl] = image
                        if let view = mapView?.view(for: marker) {
                            let sized = self.resize(image, marker.iconSize)
                            view.image = sized
                            if let height = sized?.size.height {
                                view.centerOffset = CGPoint(x: 0, y: -height / 2)
                            }
                        }
                    }
                }.resume()
            }
            return nil
        }

        // Bundled web asset - Capacitor copies the web `static/` dir into the app
        // bundle under `public/`.
        if let image = UIImage(named: "public/\(iconUrl)") {
            iconCache[iconUrl] = image
            return resize(image, marker.iconSize)
        }
        return nil
    }

    private func resize(_ image: UIImage, _ size: CGSize?) -> UIImage? {
        guard let size = size else { return image }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // MARK: Frame syncing

    func updateRender(mapBounds: CGRect) {
        DispatchQueue.main.sync {
            let newWidth = round(Double(mapBounds.width))
            let newHeight = round(Double(mapBounds.height))
            let widthEqual = round(Double(self.mapView.bounds.width)) == newWidth
            let heightEqual = round(Double(self.mapView.bounds.height)) == newHeight
            if !widthEqual || !heightEqual {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                self.mapView.frame.size.width = mapBounds.width
                self.mapView.frame.size.height = mapBounds.height
                CATransaction.commit()
            }
        }
    }

    func rebindTargetContainer(mapBounds: CGRect) {
        DispatchQueue.main.sync {
            guard let target = self.getTargetContainer(refWidth: round(Double(mapBounds.width)), refHeight: round(Double(mapBounds.height))) else { return }
            self.targetView = target
            target.tag = Map.mapTag
            target.removeAllSubview()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.mapView.frame.size.width = mapBounds.width
            self.mapView.frame.size.height = mapBounds.height
            CATransaction.commit()
            target.addSubview(self.mapView)
        }
    }

    /// Finds the WKWebView child scroll view whose content size matches the bound
    /// element, so the native map can be mounted into it. Ported from
    /// `@capacitor/google-maps`. Must be called on the main thread.
    private func getTargetContainer(refWidth: Double, refHeight: Double) -> UIView? {
        guard let webView = self.delegate?.bridge?.webView else { return nil }
        for item in webView.getAllSubViews() {
            guard let scrollView = item as? UIScrollView else { continue }
            let childScrollClass = NSClassFromString("WKChildScrollView")
            let scrollClass = NSClassFromString("WKScrollView")
            let isChildScroll = (childScrollClass != nil && item.isKind(of: childScrollClass!))
                || (scrollClass != nil && item.isKind(of: scrollClass!))
            let isBridgeScroll = item.isEqual(webView.scrollView)
            if isChildScroll && !isBridgeScroll {
                scrollView.isScrollEnabled = true
                let height = Double(scrollView.contentSize.height)
                let width = Double(scrollView.contentSize.width)
                let widthEqual = width == refWidth
                let heightEqual = floor(height / 2) == refHeight || ceil(height / 2) == refHeight
                if widthEqual && heightEqual && item.tag < (self.targetView?.tag ?? Map.mapTag) {
                    return item
                }
            }
        }
        return nil
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

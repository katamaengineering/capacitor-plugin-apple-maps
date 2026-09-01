import Foundation
import MapKit
import Capacitor

// MARK: - Plugin: camera region-change events
//
// Split out of CapacitorAppleMapsPlugin.swift so the plugin type stays within
// SwiftLint's body-length budget. These are still MKMapViewDelegate callbacks
// on the same plugin type, relaying the map's region changes to JS
// (`onCameraMoveStarted` when a move begins, `onCameraIdle` when it settles) and
// enforcing the min/max-zoom bounce.

extension CapacitorAppleMapsPlugin {

    public func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        guard let map = findMap(for: mapView) else { return }
        // The self-triggered min/max-zoom bounce (see regionDidChange) is not a
        // camera-move the caller started, so don't report it.
        if map.isAdjustingRegion { return }
        notifyListeners("onCameraMoveStarted", data: [
            "mapId": map.id,
            "isGesture": Self.regionChangeIsGesture(mapView)
        ])
    }

    /// Whether an in-flight region change originates from a user gesture rather
    /// than a programmatic move. MapKit hangs its pan/pinch/rotate recognizers on
    /// the map's first subview; if any is mid-recognition the move is a gesture.
    static func regionChangeIsGesture(_ mapView: MKMapView) -> Bool {
        guard let gestureHost = mapView.subviews.first,
              let recognizers = gestureHost.gestureRecognizers else { return false }
        return recognizers.contains { recognizer in
            switch recognizer.state {
            case .began, .changed, .ended:
                return true
            default:
                return false
            }
        }
    }

    public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        guard let map = findMap(for: mapView) else { return }

        if map.isAdjustingRegion {
            // This callback is the settle after our own clamp - clear the guard
            // and report the corrected camera.
            map.isAdjustingRegion = false
        } else if let minZoom = map.config.minZoom, map.currentZoom() < minZoom - 0.01 {
            // The user zoomed out past the floor; bounce back to it.
            map.isAdjustingRegion = true
            map.setCameraInternal(coordinate: mapView.centerCoordinate, zoom: minZoom, animate: true)
            return
        } else if let maxZoom = map.config.maxZoom, map.currentZoom() > maxZoom + 0.01 {
            // The user zoomed in past the ceiling; bounce back to it.
            map.isAdjustingRegion = true
            map.setCameraInternal(coordinate: mapView.centerCoordinate, zoom: maxZoom, animate: true)
            return
        }

        let center = mapView.centerCoordinate
        notifyListeners("onCameraIdle", data: [
            "mapId": map.id,
            "latitude": center.latitude,
            "longitude": center.longitude,
            "zoom": map.currentZoom(),
            "bounds": map.boundsPayload()
        ])
    }
}

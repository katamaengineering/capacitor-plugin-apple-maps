import Foundation
import Capacitor
import MapKit
import UIKit

/**
 * Bridges the JS API to native MapKit and relays map events back to JS.
 * See CapacitorAppleMaps.swift for the per-map implementation.
 */
@objc(CapacitorAppleMapsPlugin)
public class CapacitorAppleMapsPlugin: CAPPlugin, CAPBridgedPlugin, MKMapViewDelegate {
    public let identifier = "CapacitorAppleMapsPlugin"
    public let jsName = "CapacitorAppleMaps"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "create", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "destroy", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setCamera", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getMapBounds", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getCameraPosition", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "fitBounds", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "addMarkers", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "addMarker", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "updateMarkers", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "removeMarkers", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "removeMarker", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "enableClustering", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "disableClustering", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "addPolylines", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "addPolygons", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "addCircles", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "removeOverlays", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setMapType", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "enableCurrentLocation", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setTrafficEnabled", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setPointsOfInterestEnabled", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setCompassEnabled", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setScaleEnabled", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setColorScheme", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setGestures", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setPadding", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "takeSnapshot", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "searchAutocomplete", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "searchPlaces", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "searchResolve", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "onResize", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "onDisplay", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "onScroll", returnType: CAPPluginReturnPromise)
    ]

    private let clusterReuseId = "appleMapCluster"
    // Markers with an icon and markers without one use different view classes
    // (MKAnnotationView vs MKMarkerAnnotationView) and so must not share a reuse
    // identifier — MapKit would hand back the wrong class from the reuse pool.
    private let markerReuseId = "appleMapMarker"
    private let markerDefaultReuseId = "appleMapMarkerDefault"

    var maps = [String: Map]()
    private let searchService = SearchService()

    // MARK: - App lifecycle

    override public func load() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    /// After the app returns to the foreground WebKit can rebuild its scroll-view
    /// hierarchy, orphaning the native map's touch handling (it still renders but
    /// gestures stop working). Re-mount each map into its current container.
    @objc private func handleDidBecomeActive() {
        for (_, map) in maps {
            map.remountIntoContainer()
        }
    }

    // MARK: - Lifecycle

    @objc func create(_ call: CAPPluginCall) {
        guard let id = call.getString("id") else {
            call.reject("id is required")
            return
        }
        guard let configObj = call.getObject("config") else {
            call.reject("config is required")
            return
        }
        let forceCreate = call.getBool("forceCreate", false)

        do {
            let config = try AppleMapConfig(fromJSObject: configObj)

            if maps[id] != nil {
                if !forceCreate {
                    call.resolve()
                    return
                }
                maps.removeValue(forKey: id)?.destroy()
            }

            runOnMainSync {
                self.maps[id] = Map(id: id, config: config, delegate: self)
            }
            call.resolve()
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func destroy(_ call: CAPPluginCall) {
        guard let id = call.getString("id"), let map = maps.removeValue(forKey: id) else {
            call.reject("map not found")
            return
        }
        map.destroy()
        call.resolve()
    }

    // MARK: - Camera

    @objc func setCamera(_ call: CAPPluginCall) {
        guard let id = call.getString("id"), let map = maps[id] else {
            call.reject("map not found")
            return
        }
        let configObj = call.getObject("config") ?? [:]

        var coordinate: CLLocationCoordinate2D?
        if let coordObj = configObj["coordinate"] as? JSObject,
           let lat = coordObj["lat"] as? Double,
           let lng = coordObj["lng"] as? Double {
            coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        let zoom = configObj["zoom"] as? Double
        let animate = configObj["animate"] as? Bool ?? false

        runOnMainSync {
            map.setCameraInternal(coordinate: coordinate, zoom: zoom, animate: animate)
        }
        call.resolve()
    }

    @objc func getMapBounds(_ call: CAPPluginCall) {
        guard let id = call.getString("id"), let map = maps[id] else {
            call.reject("map not found")
            return
        }
        runOnMainSync {
            call.resolve(map.boundsPayload())
        }
    }

    @objc func getCameraPosition(_ call: CAPPluginCall) {
        guard let id = call.getString("id"), let map = maps[id] else {
            call.reject("map not found")
            return
        }
        runOnMainSync {
            call.resolve(map.cameraPayload())
        }
    }

    @objc func fitBounds(_ call: CAPPluginCall) {
        guard let id = call.getString("id"), let map = maps[id] else {
            call.reject("map not found")
            return
        }
        guard let boundsObj = call.getObject("bounds"),
              let swObj = boundsObj["southwest"] as? JSObject,
              let swLat = swObj["lat"] as? Double, let swLng = swObj["lng"] as? Double,
              let neObj = boundsObj["northeast"] as? JSObject,
              let neLat = neObj["lat"] as? Double, let neLng = neObj["lng"] as? Double else {
            call.reject("bounds with southwest and northeast is required")
            return
        }
        let padding = call.getDouble("padding") ?? 0
        let animate = call.getBool("animate", true)
        map.fitBounds(
            southwest: CLLocationCoordinate2D(latitude: swLat, longitude: swLng),
            northeast: CLLocationCoordinate2D(latitude: neLat, longitude: neLng),
            padding: padding, animate: animate
        )
        call.resolve()
    }

    // MARK: - Markers
    //
    // The marker + clustering bridge methods live in MarkerBridge.swift to keep
    // this type within SwiftLint's body-length budget.

    // MARK: - Search

    @objc func searchAutocomplete(_ call: CAPPluginCall) {
        searchService.autocomplete(call)
    }

    @objc func searchPlaces(_ call: CAPPluginCall) {
        searchService.places(call)
    }

    @objc func searchResolve(_ call: CAPPluginCall) {
        searchService.resolve(call)
    }

    // MARK: - MKMapViewDelegate
    //
    // The region-change delegate methods (onCameraMoveStarted / onCameraIdle and
    // the min/max-zoom bounce) live in CameraEvents.swift to keep this type within
    // SwiftLint's body-length budget.

    public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }

        if let cluster = annotation as? MKClusterAnnotation {
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: clusterReuseId) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: cluster, reuseIdentifier: clusterReuseId)
            view.annotation = cluster
            view.canShowCallout = false
            view.glyphText = "\(cluster.memberAnnotations.count)"
            view.markerTintColor = .systemGray
            view.displayPriority = .required
            return view
        }

        guard let marker = annotation as? AppleMapMarker, let map = findMap(for: mapView) else { return nil }

        // No icon → MapKit's native pin (MKMarkerAnnotationView), mirroring how
        // @capacitor/google-maps renders a default marker when the host supplies
        // none; a bare image-less MKAnnotationView would be invisible. The two
        // view classes can't share a reuse id.
        let hasIcon = !(marker.iconUrl?.isEmpty ?? true)
        let view: MKAnnotationView
        if hasIcon {
            view = mapView.dequeueReusableAnnotationView(withIdentifier: markerReuseId)
                ?? MKAnnotationView(annotation: marker, reuseIdentifier: markerReuseId)
        } else {
            view = mapView.dequeueReusableAnnotationView(withIdentifier: markerDefaultReuseId) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: marker, reuseIdentifier: markerDefaultReuseId)
        }
        view.annotation = marker
        view.clusteringIdentifier = map.clusteringEnabled ? clusterReuseId : nil
        view.displayPriority = .required
        // Info windows are drawn as our own bubble (see Callout.swift), so the
        // native callout stays off. When info windows are on, hide the inline
        // title/subtitle labels too, so the bubble is the sole info display.
        if let markerView = view as? MKMarkerAnnotationView {
            let visibility: MKFeatureVisibility = map.config.showInfoWindows ? .hidden : .adaptive
            markerView.titleVisibility = visibility
            markerView.subtitleVisibility = visibility
        }

        // Reset first: a recycled image view must not keep a previous marker's
        // icon while an `https:` icon for this one is still downloading (the
        // async completion in `annotationImage` sets it on the live view).
        view.image = nil
        view.centerOffset = .zero
        if hasIcon, let image = map.annotationImage(for: marker, in: mapView) {
            view.image = image
            view.centerOffset = CGPoint(x: 0, y: -image.size.height / 2)
        }
        // The native callout stays off - we render our own bubble (Callout.swift),
        // because MapKit's callout doesn't show through the web-view compositing.
        view.canShowCallout = false
        return view
    }

    public func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let map = findMap(for: mapView) else { return }

        if let cluster = view.annotation as? MKClusterAnnotation {
            mapView.deselectAnnotation(cluster, animated: false)
            notifyListeners("onClusterClick", data: [
                "mapId": map.id,
                "latitude": cluster.coordinate.latitude,
                "longitude": cluster.coordinate.longitude,
                "count": cluster.memberAnnotations.count,
                "markerIds": cluster.memberAnnotations.compactMap { ($0 as? AppleMapMarker)?.markerId }
            ])
            // Expand the cluster by zooming to fit its members.
            var rect = MKMapRect.null
            for member in cluster.memberAnnotations {
                let point = MKMapPoint(member.coordinate)
                rect = rect.union(MKMapRect(x: point.x, y: point.y, width: 0.01, height: 0.01))
            }
            let padding = UIEdgeInsets(top: 60, left: 60, bottom: 60, right: 60)
            mapView.setVisibleMapRect(rect, edgePadding: padding, animated: true)
            return
        }

        guard let marker = view.annotation as? AppleMapMarker else { return }
        notifyListeners("onMarkerClick", data: [
            "mapId": map.id,
            "markerId": marker.markerId,
            "latitude": marker.coordinate.latitude,
            "longitude": marker.coordinate.longitude,
            "title": marker.title ?? ""
        ])

        // Never keep MapKit's selected (enlarged) state; deselect right away so the
        // pin stays its normal size, then show our own info-window bubble instead
        // (the native callout doesn't render through the web-view compositing).
        mapView.deselectAnnotation(marker, animated: false)
        if map.config.showInfoWindows && !(marker.title?.isEmpty ?? true) {
            map.showCallout(for: marker)
        } else {
            map.dismissCallout()
        }
    }

    // MARK: - Helpers

    func findMap(for mapView: MKMapView) -> Map? {
        for (_, map) in maps where map.mapView === mapView {
            return map
        }
        return nil
    }
}

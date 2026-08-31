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
        CAPPluginMethod(name: "addMarkers", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "removeMarkers", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "enableClustering", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "disableClustering", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "searchAutocomplete", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "searchPlaces", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "searchResolve", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "onResize", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "onDisplay", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "onScroll", returnType: CAPPluginReturnPromise)
    ]

    private let clusterReuseId = "appleMapCluster"
    private let markerReuseId = "appleMapMarker"

    private var maps = [String: Map]()
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

            DispatchQueue.main.sync {
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

        DispatchQueue.main.sync {
            map.setCameraInternal(coordinate: coordinate, zoom: zoom, animate: animate)
        }
        call.resolve()
    }

    @objc func getMapBounds(_ call: CAPPluginCall) {
        guard let id = call.getString("id"), let map = maps[id] else {
            call.reject("map not found")
            return
        }
        DispatchQueue.main.sync {
            call.resolve(map.boundsPayload())
        }
    }

    // MARK: - Markers

    @objc func addMarkers(_ call: CAPPluginCall) {
        guard let id = call.getString("id"), let map = maps[id] else {
            call.reject("map not found")
            return
        }
        guard let markerObjs = call.getArray("markers") as? [JSObject] else {
            call.reject("markers array is required")
            return
        }
        let ids = map.addMarkers(markerObjs)
        call.resolve(["ids": ids])
    }

    @objc func removeMarkers(_ call: CAPPluginCall) {
        guard let id = call.getString("id"), let map = maps[id] else {
            call.reject("map not found")
            return
        }
        guard let ids = call.getArray("markerIds") as? [String] else {
            call.reject("markerIds array is required")
            return
        }
        map.removeMarkers(ids)
        call.resolve()
    }

    @objc func enableClustering(_ call: CAPPluginCall) {
        guard let id = call.getString("id"), let map = maps[id] else {
            call.reject("map not found")
            return
        }
        map.enableClustering()
        call.resolve()
    }

    @objc func disableClustering(_ call: CAPPluginCall) {
        guard let id = call.getString("id"), let map = maps[id] else {
            call.reject("map not found")
            return
        }
        map.disableClustering()
        call.resolve()
    }

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

    // MARK: - Frame syncing

    @objc func onResize(_ call: CAPPluginCall) {
        guard let id = call.getString("id"), let map = maps[id] else {
            call.reject("map not found")
            return
        }
        guard let boundsObj = call.getObject("mapBounds") else {
            call.reject("mapBounds is required")
            return
        }
        map.updateRender(mapBounds: CGRect.fromJSObject(boundsObj))
        call.resolve()
    }

    @objc func onDisplay(_ call: CAPPluginCall) {
        guard let id = call.getString("id"), let map = maps[id] else {
            call.reject("map not found")
            return
        }
        guard let boundsObj = call.getObject("mapBounds") else {
            call.reject("mapBounds is required")
            return
        }
        map.rebindTargetContainer(mapBounds: CGRect.fromJSObject(boundsObj))
        call.resolve()
    }

    @objc func onScroll(_ call: CAPPluginCall) {
        // The native map is a subview inside the webview's own scroll view on
        // iOS, so it tracks page scrolling automatically. Nothing to do.
        call.resolve()
    }

    // MARK: - MKMapViewDelegate

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

        let view = mapView.dequeueReusableAnnotationView(withIdentifier: markerReuseId)
            ?? MKAnnotationView(annotation: marker, reuseIdentifier: markerReuseId)
        view.annotation = marker
        view.canShowCallout = false
        view.clusteringIdentifier = map.clusteringEnabled ? clusterReuseId : nil
        view.displayPriority = .required

        if let image = map.annotationImage(for: marker, in: mapView) {
            view.image = image
            view.centerOffset = CGPoint(x: 0, y: -image.size.height / 2)
        }
        return view
    }

    public func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let map = findMap(for: mapView) else { return }

        if let cluster = view.annotation as? MKClusterAnnotation {
            // Expand the cluster by zooming to fit its members.
            mapView.deselectAnnotation(cluster, animated: false)
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
        // Deselect immediately so the same pin can be tapped again.
        mapView.deselectAnnotation(marker, animated: false)
        notifyListeners("onMarkerClick", data: [
            "mapId": map.id,
            "markerId": marker.markerId,
            "latitude": marker.coordinate.latitude,
            "longitude": marker.coordinate.longitude,
            "title": marker.title ?? ""
        ])
    }

    // MARK: - Helpers

    private func findMap(for mapView: MKMapView) -> Map? {
        for (_, map) in maps where map.mapView === mapView {
            return map
        }
        return nil
    }
}

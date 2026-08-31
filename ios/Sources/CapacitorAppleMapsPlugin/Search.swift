import Foundation
import MapKit
import Capacitor

/// True when `coordinate` is within `maxKm` of `center`. A nil/zero limit or a
/// nil center means "no filter" (always true). Pure so it can be unit-tested.
func withinDistance(maxKm: Double?, from center: CLLocation?, to coordinate: CLLocationCoordinate2D) -> Bool {
    guard let maxKm = maxKm, maxKm > 0, let center = center else { return true }
    let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    return center.distance(from: here) / 1000.0 <= maxKm
}

/// Reads an optional `region` object into an `MKCoordinateRegion` and its center.
private func parseRegion(_ region: JSObject?) -> (region: MKCoordinateRegion, center: CLLocation)? {
    guard let region = region,
          let lat = region["latitude"] as? Double,
          let lng = region["longitude"] as? Double else { return nil }
    let latDelta = region["latitudeDelta"] as? Double ?? 1.0
    let lngDelta = region["longitudeDelta"] as? Double ?? 1.0
    let center = CLLocationCoordinate2D(latitude: lat, longitude: lng)
    return (
        MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lngDelta)),
        CLLocation(latitude: lat, longitude: lng)
    )
}

/// A "City, State" style secondary line, skipping the locality when it just
/// repeats the primary name.
private func placeSubtitle(for placemark: MKPlacemark, name: String?) -> String {
    var parts: [String] = []
    if let locality = placemark.locality, locality != name {
        parts.append(locality)
    }
    if let admin = placemark.administrativeArea {
        parts.append(admin)
    }
    if parts.isEmpty, let country = placemark.country {
        parts.append(country)
    }
    return parts.joined(separator: ", ")
}

/// Native place search. Offers two independent APIs:
///
/// - `autocomplete` / `resolve`: idiomatic type-ahead via `MKLocalSearchCompleter`,
///   returning lightweight `{id, title, subtitle}` completions that `resolve`
///   turns into coordinates on demand.
/// - `places`: a one-shot `MKLocalSearch` returning coordinate-bearing results,
///   optionally scoped to a region and filtered by distance.
///
/// Both kinds of id resolve through `resolve`.
class SearchService: NSObject, MKLocalSearchCompleterDelegate {
    // Autocomplete (MKLocalSearchCompleter)
    private var completer: MKLocalSearchCompleter?
    private var pendingCall: CAPPluginCall?
    private var completions: [String: MKLocalSearchCompletion] = [:]

    // One-shot search (MKLocalSearch)
    private var items: [String: MKMapItem] = [:]
    private var currentSearch: MKLocalSearch?

    // MARK: - Autocomplete (type-ahead)

    private func ensureCompleter() {
        if completer == nil {
            let newCompleter = MKLocalSearchCompleter()
            newCompleter.resultTypes = [.address, .pointOfInterest]
            newCompleter.delegate = self
            completer = newCompleter
        }
    }

    func autocomplete(_ call: CAPPluginCall) {
        let query = call.getString("query") ?? ""
        let regionObj = call.getObject("region")
        DispatchQueue.main.async {
            self.pendingCall?.resolve(["results": []])

            if query.isEmpty {
                self.pendingCall = nil
                call.resolve(["results": []])
                return
            }

            self.ensureCompleter()
            guard let completer = self.completer else {
                call.resolve(["results": []])
                return
            }

            if let parsed = parseRegion(regionObj) {
                completer.region = parsed.region
            }

            self.pendingCall = call
            completer.queryFragment = query
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard let call = pendingCall else { return }
        pendingCall = nil

        if completions.count > 300 {
            completions.removeAll()
        }

        var results: [[String: Any]] = []
        for completion in completer.results {
            let id = UUID().uuidString
            completions[id] = completion
            results.append([
                "id": id,
                "title": completion.title,
                "subtitle": completion.subtitle
            ])
        }
        call.resolve(["results": results])
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        pendingCall?.resolve(["results": []])
        pendingCall = nil
    }

    // MARK: - One-shot search (coordinate-bearing, filterable)

    func places(_ call: CAPPluginCall) {
        let query = call.getString("query") ?? ""
        if query.isEmpty {
            call.resolve(["results": []])
            return
        }

        let regionObj = call.getObject("region")
        let maxDistanceKm = call.getDouble("maxDistanceKm")
        let limit = call.getInt("limit")

        DispatchQueue.main.async {
            self.currentSearch?.cancel()

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query

            var center: CLLocation?
            if let parsed = parseRegion(regionObj) {
                request.region = parsed.region
                center = parsed.center
            }

            let search = MKLocalSearch(request: request)
            self.currentSearch = search
            search.start { response, _ in
                if self.items.count > 300 {
                    self.items.removeAll()
                }

                var results: [[String: Any]] = []
                for item in response?.mapItems ?? [] {
                    let coordinate = item.placemark.coordinate
                    guard withinDistance(maxKm: maxDistanceKm, from: center, to: coordinate) else { continue }

                    let id = UUID().uuidString
                    self.items[id] = item
                    results.append([
                        "id": id,
                        "title": item.name ?? item.placemark.locality ?? "",
                        "subtitle": placeSubtitle(for: item.placemark, name: item.name),
                        "latitude": coordinate.latitude,
                        "longitude": coordinate.longitude
                    ])

                    if let limit = limit, limit > 0, results.count >= limit { break }
                }
                call.resolve(["results": results])
            }
        }
    }

    // MARK: - Resolve (either kind of id)

    func resolve(_ call: CAPPluginCall) {
        guard let id = call.getString("id") else {
            call.resolve([:])
            return
        }

        // A `places` result already carries its coordinate.
        if let item = items[id] {
            let coordinate = item.placemark.coordinate
            call.resolve([
                "lat": coordinate.latitude,
                "lng": coordinate.longitude,
                "title": item.name ?? ""
            ])
            return
        }

        // An `autocomplete` completion needs a search to get its coordinate.
        guard let completion = completions[id] else {
            call.resolve([:])
            return
        }
        DispatchQueue.main.async {
            let search = MKLocalSearch(request: MKLocalSearch.Request(completion: completion))
            search.start { response, _ in
                guard let item = response?.mapItems.first else {
                    call.resolve([:])
                    return
                }
                let coordinate = item.placemark.coordinate
                call.resolve([
                    "lat": coordinate.latitude,
                    "lng": coordinate.longitude,
                    "title": item.name ?? completion.title
                ])
            }
        }
    }
}

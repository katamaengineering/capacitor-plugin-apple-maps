import Foundation
import MapKit
import Capacitor

/// Native place search with no third-party key: `MKLocalSearchCompleter` for
/// autocomplete and `MKLocalSearch` to resolve a chosen suggestion to
/// coordinates. Completions cannot cross the JS bridge, so they are held here
/// keyed by an opaque id that JS echoes back to `resolve`.
class SearchService: NSObject, MKLocalSearchCompleterDelegate {
    private var completer: MKLocalSearchCompleter?
    private var pendingCall: CAPPluginCall?
    private var completions: [String: MKLocalSearchCompletion] = [:]

    /// Lazily create the completer on the main thread — MapKit delivers its
    /// delegate callbacks on the run loop it is configured on.
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
        DispatchQueue.main.async {
            // Only the newest query matters; settle any in-flight call so its
            // promise never dangles.
            self.pendingCall?.resolve(["results": []])

            if query.isEmpty {
                self.pendingCall = nil
                call.resolve(["results": []])
                return
            }

            self.ensureCompleter()
            self.pendingCall = call
            self.completer?.queryFragment = query
        }
    }

    func resolve(_ call: CAPPluginCall) {
        guard let id = call.getString("id"), let completion = completions[id] else {
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

    // MARK: - MKLocalSearchCompleterDelegate

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard let call = pendingCall else { return }
        pendingCall = nil

        // Keep the completion store bounded across a long session.
        if completions.count > 200 {
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
}

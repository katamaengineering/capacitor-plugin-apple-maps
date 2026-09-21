import Foundation
import CoreLocation
import Contacts
import Capacitor

/// Collapses a multi-line postal address (as `CNPostalAddressFormatter` writes
/// it) into one comma-separated line, dropping blank lines. Pure so it can be
/// unit-tested.
func singleLineAddress(_ multiline: String) -> String {
    return multiline
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
}

/// Joins whatever address parts exist, skipping nil/empty ones and immediate
/// repeats (a placemark's `name` is often just its locality). Nil when nothing
/// usable remains. Pure so it can be unit-tested.
func joinedAddressParts(_ parts: [String?]) -> String? {
    var kept: [String] = []
    for part in parts {
        guard let part = part?.trimmingCharacters(in: .whitespaces), !part.isEmpty, part != kept.last else { continue }
        kept.append(part)
    }
    return kept.isEmpty ? nil : kept.joined(separator: ", ")
}

/// One display line for a placemark. Prefers the locale-aware postal format
/// (which knows, e.g., that a German postal code precedes the city); falls back
/// to the loose parts for places with no postal address, like open water.
private func formattedAddress(for placemark: CLPlacemark) -> String? {
    if let postal = placemark.postalAddress {
        let line = singleLineAddress(CNPostalAddressFormatter.string(from: postal, style: .mailingAddress))
        if !line.isEmpty { return line }
    }
    return joinedAddressParts([placemark.name, placemark.locality, placemark.administrativeArea, placemark.country])
}

/// The bridge payload for a placemark. Absent fields are omitted, not null.
private func placePayload(for placemark: CLPlacemark) -> [String: Any] {
    var payload: [String: Any] = [:]
    if let coordinate = placemark.location?.coordinate {
        payload["latitude"] = coordinate.latitude
        payload["longitude"] = coordinate.longitude
    }
    let street = [placemark.subThoroughfare, placemark.thoroughfare].compactMap { $0 }.joined(separator: " ")
    let fields: [String: String?] = [
        "address": formattedAddress(for: placemark),
        "name": placemark.name,
        "street": street,
        "locality": placemark.locality,
        "subLocality": placemark.subLocality,
        "administrativeArea": placemark.administrativeArea,
        "postalCode": placemark.postalCode,
        "country": placemark.country,
        "countryCode": placemark.isoCountryCode
    ]
    for (key, value) in fields {
        if let value = value, !value.isEmpty { payload[key] = value }
    }
    return payload
}

/// Native geocoding via `CLGeocoder`, in both directions. Needs no API key.
///
/// Both fail soft, like search: no match, an offline device, or Apple's rate
/// limit resolve an empty object rather than rejecting, because callers show an
/// address as a nicety and must never be blocked by its absence.
class GeocodeService {
    private func locale(_ call: CAPPluginCall) -> Locale? {
        guard let language = call.getString("language"), !language.isEmpty else { return nil }
        return Locale(identifier: language)
    }

    func reverse(_ call: CAPPluginCall) {
        guard let lat = call.getDouble("latitude"), let lng = call.getDouble("longitude"),
              CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lng)) else {
            call.resolve([:])
            return
        }
        // A geocoder runs one request at a time, so each call gets its own; the
        // completion handler keeps it alive until it answers.
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: lat, longitude: lng)
        geocoder.reverseGeocodeLocation(location, preferredLocale: locale(call)) { placemarks, _ in
            _ = geocoder
            guard let placemark = placemarks?.first else {
                call.resolve([:])
                return
            }
            call.resolve(placePayload(for: placemark))
        }
    }

    func forward(_ call: CAPPluginCall) {
        let address = (call.getString("address") ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if address.isEmpty {
            call.resolve([:])
            return
        }
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address, in: nil, preferredLocale: locale(call)) { placemarks, _ in
            _ = geocoder
            guard let placemark = placemarks?.first, placemark.location != nil else {
                call.resolve([:])
                return
            }
            call.resolve(placePayload(for: placemark))
        }
    }
}

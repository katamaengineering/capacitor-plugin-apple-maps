# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.2]

### Fixed

- Markers with no `iconUrl` are now drawn with MapKit's native pin
  (`MKMarkerAnnotationView`) instead of a bare, image-less `MKAnnotationView`,
  which rendered nothing. This restores parity with `@capacitor/google-maps`,
  whose markers fall back to a default pin - a marker created against the shared
  API is now visible on iOS instead of silently invisible. Icon and no-icon
  markers use separate reuse identifiers (their view classes differ), and a
  recycled image view is cleared before reuse so it cannot flash a previous
  marker's icon while an `https:` icon is still downloading.

## [0.3.1]

### Fixed

- The map could lock up (still visible but unresponsive to gestures) after the
  app was backgrounded and returned to the foreground. The plugin now re-mounts
  each map into its webview container on `didBecomeActive`, restoring touch.

## [0.3.0]

### Added

- `searchPlaces`: a one-shot `MKLocalSearch` returning coordinate-bearing
  results (`SearchResult`), with optional region scoping, a `maxDistanceKm`
  distance filter (drop far-away same-named places), and a result `limit`.
- `searchResolve` now resolves ids from either `searchAutocomplete` or
  `searchPlaces`.

`searchAutocomplete` is unchanged - it remains idiomatic `MKLocalSearchCompleter`
type-ahead. Use `searchPlaces` when you need coordinates up front or filtering.

## [0.2.0]

### Added

- `searchAutocomplete` accepts an optional `region` to bias native place
  suggestions toward the area in view (sets `MKLocalSearchCompleter.region`), so
  a query favours nearby results instead of same-named places elsewhere.

### Changed

- Extracted the visible-bounds math out of `boundsPayload()` into a pure
  `regionCorners(center:span:)` helper.

### Tests

- Expanded the Swift suite from 2 to 10 cases: config parsing, bounds math,
  and zoom conversion edge cases.

## [0.1.0]

### Added

- Native place search with no API key: `searchAutocomplete`
  (`MKLocalSearchCompleter`) for suggestions and `searchResolve`
  (`MKLocalSearch`) to turn a suggestion into coordinates.

## [0.0.1]

### Added

- Initial release: native Apple Maps (MapKit) for Capacitor on iOS. Renders a
  native map under the web view, with camera control, markers with custom
  icons, native annotation clustering, marker-tap and camera-idle events, and an
  `AppleMap` wrapper that mirrors the `@capacitor/google-maps` API surface used
  by the host app.

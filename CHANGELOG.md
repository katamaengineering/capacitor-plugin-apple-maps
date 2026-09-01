# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0]

### Added

- **`onCameraMoveStarted` event** (`setOnCameraMoveStartedListener`). Fires once
  when the camera begins moving, before `onCameraIdle`, carrying an `isGesture`
  flag that distinguishes a user pan/zoom from a programmatic `setCamera` /
  `fitBounds` move. The self-triggered min/max-zoom bounce is not reported.
- **`addMarker(marker)` / `removeMarker(id)`.** Single-marker convenience over
  the batch `addMarkers` / `removeMarkers`; `addMarker` returns the new id.
- **`fitBounds` now also accepts a raw `LatLng[]`.** Pass the coordinates
  directly (e.g. every pin's `coordinate` after `addMarkers`) and the wrapper
  computes the bounding box for you, instead of building a `LatLngBounds` by hand.
- **Draggable markers + drag events.** Mark a pin `draggable: true` (on
  `addMarkers` / `addMarker`, or toggled via `updateMarkers`) to let the user
  press-and-hold and drag it. `onMarkerDragStart`, `onMarkerDrag` (continuous),
  and `onMarkerDragEnd` each carry the pin's live coordinate. Driven by a
  long-press recognizer on the map (not `MKAnnotationView.isDraggable`), so the
  intermediate coordinates stream rather than only the drop point; a pin that is
  currently clustered can't be dragged until it separates.
- **Appearance toggles.** `setTrafficEnabled`, `setPointsOfInterestEnabled`,
  `setCompassEnabled`, `setScaleEnabled`, and `setColorScheme('default' | 'light'
  | 'dark')` control the corresponding `MKMapView` properties at runtime. Each
  also has an `AppleMapConfig` field applied at create time (`showsTraffic`,
  `showsPointsOfInterest`, `showsCompass`, `showsScale`, `colorScheme`); the
  defaults mirror MapKit's own (traffic/scale off, POI/compass on, system scheme).

## [0.4.0]

### Added

- **Overlays.** `addPolylines`, `addPolygons` (with holes), and `addCircles`
  return ids; `removeOverlays` takes ids from any of them. Each accepts hex
  stroke/fill colors (`#RRGGBB` or `#RRGGBBAA`) with an optional `strokeOpacity`
  / `fillOpacity` override, drawn natively via `MKOverlayRenderer`.
- **`fitBounds(bounds, padding?)`.** Frame a `LatLngBounds` in the viewport,
  inset by `padding` points, via `setVisibleMapRect(_:edgePadding:)` - handy for
  framing every pin after `addMarkers`.
- **`getCameraPosition`.** Read the current camera as
  `{ latitude, longitude, zoom, bounds }` (the write side, `setCamera`, already
  existed).
- **`updateMarkers`.** Apply partial changes to existing markers by `markerId`:
  a moved marker animates to its new coordinate; title/icon changes rebuild the
  pin in place. `Marker` also accepts a caller-supplied `markerId` so the host
  can map pins back to its own domain objects instead of tracking generated ids.
- **`onMapClick` event** (`setOnMapClickListener`). Fires for taps on the map
  surface, ignoring taps that land on a marker (those still report via
  `onMarkerClick`).
- **`onMapLongClick` event** (`setOnMapLongClickListener`). Fires for a long-press
  on the map surface (again ignoring presses on a marker).
- **`onClusterClick` event** (`setOnClusterClickListener`). Fires when a cluster
  bubble is tapped, carrying the cluster's coordinate, member `count`, and the
  member `markerIds`. The existing zoom-to-fit-members behavior is unchanged.
- **Native info windows** (`AppleMapConfig.showInfoWindows`, default `false`).
  When enabled, tapping a marker that has a `title` shows MapKit's native callout
  bubble (with an optional `Marker.snippet` as the second line) instead of
  deselecting immediately. `onMarkerClick` still fires either way.
- **`setMapType` / `AppleMapConfig.mapType`.** Choose the base imagery
  (`standard`, `satellite`, `hybrid`, `satelliteFlyover`, `hybridFlyover`,
  `mutedStandard`).
- **`enableCurrentLocation(enabled)`.** Show or hide the blue user-location dot.
  The host app is responsible for `NSLocationWhenInUseUsageDescription` and for
  obtaining location permission.

### Fixed

- **`maxZoom` was accepted but ignored.** It is now enforced as a zoom-in
  ceiling - clamped in programmatic camera moves and bounced back on gesture -
  symmetric with the existing `minZoom` floor.
- **Marker icon cache no longer grows without bound.** The per-map icon cache is
  now an `NSCache` (capped, and evicted under memory pressure) instead of a
  dictionary that retained every distinct icon for the life of the map.
- **`removeMarkers` / `removeOverlays` now accept id arrays held in reactive
  state.** A reactive-framework proxy array (Svelte `$state`, a Vue ref, …) does
  not survive Capacitor's bridge serialization as an array, so the native side
  saw no ids and rejected the call with "…array is required". Both wrappers now
  copy the ids into a plain array before the call. (`removeMarkers` had this
  latent since its introduction; `removeOverlays` is new in this release.)
- **Remote marker icons are no longer re-downloaded on every re-render.**
  Concurrent requests for the same url are de-duped, and a url that returns no
  usable image (e.g. a 404 body or undecodable content) is remembered so it is
  not re-fetched each time annotations are rebuilt (such as on a clustering
  toggle). Transient transport errors (offline, timeout) are not cached, so a
  later render can still retry them.

### Changed

- The native implementation was split into `Overlays.swift` (overlay drawing,
  map type, user location, map-tap, and shared parsing/color helpers),
  `MapMounting.swift` (the web-view compositing and frame-sync glue), and
  `MarkerIcons.swift` (marker icon resolution and caching), keeping the core
  `Map` and plugin types readable. No behavior change.

### Tests

- Expanded the Swift suite from 12 to 36 cases (including a regression test that
  a `CAPPluginCall` reads a JS string array, pinning down where the `removeOverlays`
  bug was *not*). To make the marker/overlay bridge logic and zoom clamping
  testable without a UI harness, their pure cores were
  extracted - `clampZoom`, `boundingMapRect` (the `fitBounds` framing rect),
  `Map.makeMarker` (marker payload parsing), and `Map.overlayStyle` (overlay
  stroke/fill resolution) - and each is now covered, alongside map-type mapping,
  overlay coordinate/ring parsing, hex color parsing, and
  `maxZoom`/`mapType`/`showInfoWindows` config parsing.
- The example app now doubles as an on-device smoke test: on iOS it auto-runs a
  scripted sequence over the new APIs (`getCameraPosition`, overlays, `fitBounds`,
  `updateMarkers`), shows each as a ✓/✗ checklist, wires up the `onMapClick` /
  `onMapLongClick` / `onClusterClick` / `onMarkerClick` listeners, and adds
  buttons for `setMapType`, `fitBounds`, `removeOverlays`, and
  `enableCurrentLocation`. The Android/web (Google Maps) path is unchanged.

## [0.3.4]

### Added

- `create` accepts a `clustering` flag on its config. When `true`, the map starts
  with clustering enabled, so markers added afterwards cluster on their first
  render instead of briefly flashing as individual pins before a later
  `enableClustering` call collapses them. Equivalent to calling
  `enableClustering` before the first `addMarkers`, without the flash.

## [0.3.3]

### Fixed

- `AppleMap.create` could resolve with an invisible (blank) map, intermittently
  and especially after a warm relaunch. A flex/grid child gets its full width a
  frame or two before its height and final position, and `create` measured the
  element too early, placing the native map against a stale frame. `create` now
  waits for the element's box to **settle** (non-zero and unchanged across a few
  frames) before measuring, and the size wait requires a non-zero width **and**
  height (previously width only). Callers no longer need to poll for layout
  themselves before creating the map.

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

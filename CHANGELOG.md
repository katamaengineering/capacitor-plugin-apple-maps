# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

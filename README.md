# capacitor-plugin-apple-maps

[![npm version](https://img.shields.io/npm/v/capacitor-plugin-apple-maps.svg)](https://www.npmjs.com/package/capacitor-plugin-apple-maps)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->

[![All Contributors](https://img.shields.io/badge/all_contributors-1-orange.svg?style=flat-square)](#contributors-)

<!-- ALL-CONTRIBUTORS-BADGE:END -->

Renders a **native Apple Maps (MapKit)** view on iOS from a Capacitor app. The
`AppleMap` wrapper class deliberately mirrors the core subset of
[`@capacitor/google-maps`](https://github.com/ionic-team/capacitor-plugins/tree/main/google-maps)'
`GoogleMap` API - create, camera, markers, clustering, and camera-idle /
marker-click events - so an app can route **iOS to Apple Maps and Android/web to
Google Maps** behind one thin abstraction.

- **iOS only.** MapKit is a native iOS framework and needs no API key. On web
  and Android every method rejects with `unavailable` - the host app is expected
  to use another provider on those platforms.
- **No external dependencies.** Uses the system `MapKit` framework; the only SPM
  dependency is `capacitor-swift-pm`.
- Requires **iOS 15+** (matches the Capacitor 8 baseline).

## Install

```bash
npm install capacitor-plugin-apple-maps
npx cap sync ios
```

## Usage

Bind the map to a `<capacitor-apple-map>` element (registered automatically when
you import the wrapper):

```html
<capacitor-apple-map id="map" style="position:absolute; inset:0"></capacitor-apple-map>
```

```ts
import { AppleMap } from 'capacitor-plugin-apple-maps';

const map = await AppleMap.create({
  id: 'map',
  element: document.getElementById('map')!,
  config: {
    center: { lat: 42.36, lng: -71.06 },
    zoom: 11,
    minZoom: 7,
  },
});

await map.setOnMarkerClickListener((data) => console.log('tapped', data.markerId));
await map.setOnCameraIdleListener((data) => console.log('idle at', data.zoom, data.bounds));

const ids = await map.addMarkers([
  { coordinate: { lat: 42.36, lng: -71.06 }, iconUrl: 'marker-blue.png', iconSize: { width: 30, height: 36 } },
]);
await map.enableClustering();
```

A marker with **no `iconUrl`** draws MapKit's native pin
(`MKMarkerAnnotationView`), the same way `@capacitor/google-maps` falls back to a
default marker - so a marker written against the shared API is always visible.
Supply an `iconUrl` to use your own art, resolved from three sources: a **bundled
web asset** filename (copied into the app bundle under `public/` - e.g.
`marker-blue.png` from your web `static/`), an **`https:` URL**, or a **`data:`
URI**. SVG is not supported.

### Sharing one abstraction with `@capacitor/google-maps`

The wrapper's method names and payload shapes (`LatLng`, `LatLngBounds`,
`CameraIdleCallbackData`, `MarkerClickCallbackData`) match `@capacitor/google-maps`,
so a host app can pick the provider per platform:

```ts
const map =
  Capacitor.getPlatform() === 'ios'
    ? await AppleMap.create({ id, element, config })
    : await GoogleMap.create({ id, element, apiKey, config });
```

## Notes & limitations

- **Zoom is approximated.** MapKit uses region spans, not Google's integer
  zoom; the plugin converts using the web-mercator tile relationship. Reported
  zoom round-trips but is not pixel-identical to Google.
- **Cluster taps zoom to fit** the cluster members (Apple-native behaviour)
  rather than firing an event.
- `minZoom` is enforced on programmatic moves and by bouncing back a gesture
  that overshoots the floor. `maxZoom` is currently advisory.

## API

<docgen-index>

* [`create(...)`](#create)
* [`destroy(...)`](#destroy)
* [`setCamera(...)`](#setcamera)
* [`getMapBounds(...)`](#getmapbounds)
* [`getCameraPosition(...)`](#getcameraposition)
* [`fitBounds(...)`](#fitbounds)
* [`addMarkers(...)`](#addmarkers)
* [`addMarker(...)`](#addmarker)
* [`updateMarkers(...)`](#updatemarkers)
* [`removeMarkers(...)`](#removemarkers)
* [`removeMarker(...)`](#removemarker)
* [`enableClustering(...)`](#enableclustering)
* [`disableClustering(...)`](#disableclustering)
* [`addPolylines(...)`](#addpolylines)
* [`addPolygons(...)`](#addpolygons)
* [`addCircles(...)`](#addcircles)
* [`removeOverlays(...)`](#removeoverlays)
* [`setMapType(...)`](#setmaptype)
* [`enableCurrentLocation(...)`](#enablecurrentlocation)
* [`setTrafficEnabled(...)`](#settrafficenabled)
* [`setPointsOfInterestEnabled(...)`](#setpointsofinterestenabled)
* [`setCompassEnabled(...)`](#setcompassenabled)
* [`setScaleEnabled(...)`](#setscaleenabled)
* [`setColorScheme(...)`](#setcolorscheme)
* [`searchAutocomplete(...)`](#searchautocomplete)
* [`searchPlaces(...)`](#searchplaces)
* [`searchResolve(...)`](#searchresolve)
* [`onResize(...)`](#onresize)
* [`onDisplay(...)`](#ondisplay)
* [`onScroll(...)`](#onscroll)
* [`addListener('onCameraIdle', ...)`](#addlisteneroncameraidle-)
* [`addListener('onMarkerClick', ...)`](#addlisteneronmarkerclick-)
* [`addListener('onMapReady', ...)`](#addlisteneronmapready-)
* [`addListener('onMapClick', ...)`](#addlisteneronmapclick-)
* [`addListener('onMapLongClick', ...)`](#addlisteneronmaplongclick-)
* [`addListener('onClusterClick', ...)`](#addlisteneronclusterclick-)
* [`addListener('onCameraMoveStarted', ...)`](#addlisteneroncameramovestarted-)
* [`addListener('onMarkerDragStart', ...)`](#addlisteneronmarkerdragstart-)
* [`addListener('onMarkerDrag', ...)`](#addlisteneronmarkerdrag-)
* [`addListener('onMarkerDragEnd', ...)`](#addlisteneronmarkerdragend-)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

Low-level bridge to the native MapKit implementation. Most callers should use
the {@link AppleMap} wrapper instead of these methods directly.

### create(...)

```typescript
create(options: { id: string; config: AppleMapConfig; element?: unknown; forceCreate?: boolean; }) => Promise<void>
```

| Param         | Type                                                                                                                         |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| **`options`** | <code>{ id: string; config: <a href="#applemapconfig">AppleMapConfig</a>; element?: unknown; forceCreate?: boolean; }</code> |

--------------------


### destroy(...)

```typescript
destroy(options: { id: string; }) => Promise<void>
```

| Param         | Type                         |
| ------------- | ---------------------------- |
| **`options`** | <code>{ id: string; }</code> |

--------------------


### setCamera(...)

```typescript
setCamera(options: { id: string; config: CameraConfig; }) => Promise<void>
```

| Param         | Type                                                                           |
| ------------- | ------------------------------------------------------------------------------ |
| **`options`** | <code>{ id: string; config: <a href="#cameraconfig">CameraConfig</a>; }</code> |

--------------------


### getMapBounds(...)

```typescript
getMapBounds(options: { id: string; }) => Promise<LatLngBounds>
```

| Param         | Type                         |
| ------------- | ---------------------------- |
| **`options`** | <code>{ id: string; }</code> |

**Returns:** <code>Promise&lt;<a href="#latlngbounds">LatLngBounds</a>&gt;</code>

--------------------


### getCameraPosition(...)

```typescript
getCameraPosition(options: { id: string; }) => Promise<CameraPosition>
```

Current camera as `{ latitude, longitude, zoom, bounds }`.

| Param         | Type                         |
| ------------- | ---------------------------- |
| **`options`** | <code>{ id: string; }</code> |

**Returns:** <code>Promise&lt;<a href="#cameraposition">CameraPosition</a>&gt;</code>

--------------------


### fitBounds(...)

```typescript
fitBounds(options: { id: string; bounds: LatLngBounds; padding?: number; animate?: boolean; }) => Promise<void>
```

Move the camera to fit `bounds`, insetting the visible rect by `padding`
points on every side (default `0`). Animates unless `animate` is `false`.

| Param         | Type                                                                                                                |
| ------------- | ------------------------------------------------------------------------------------------------------------------- |
| **`options`** | <code>{ id: string; bounds: <a href="#latlngbounds">LatLngBounds</a>; padding?: number; animate?: boolean; }</code> |

--------------------


### addMarkers(...)

```typescript
addMarkers(options: { id: string; markers: Marker[]; }) => Promise<{ ids: string[]; }>
```

| Param         | Type                                            |
| ------------- | ----------------------------------------------- |
| **`options`** | <code>{ id: string; markers: Marker[]; }</code> |

**Returns:** <code>Promise&lt;{ ids: string[]; }&gt;</code>

--------------------


### addMarker(...)

```typescript
addMarker(options: { id: string; marker: Marker; }) => Promise<{ id: string; }>
```

Add a single marker, returning its id. Convenience over {@link addMarkers}.

| Param         | Type                                                               |
| ------------- | ------------------------------------------------------------------ |
| **`options`** | <code>{ id: string; marker: <a href="#marker">Marker</a>; }</code> |

**Returns:** <code>Promise&lt;{ id: string; }&gt;</code>

--------------------


### updateMarkers(...)

```typescript
updateMarkers(options: { id: string; markers: MarkerUpdate[]; }) => Promise<void>
```

Apply partial changes to existing markers, addressed by `markerId`.

| Param         | Type                                                  |
| ------------- | ----------------------------------------------------- |
| **`options`** | <code>{ id: string; markers: MarkerUpdate[]; }</code> |

--------------------


### removeMarkers(...)

```typescript
removeMarkers(options: { id: string; markerIds: string[]; }) => Promise<void>
```

| Param         | Type                                              |
| ------------- | ------------------------------------------------- |
| **`options`** | <code>{ id: string; markerIds: string[]; }</code> |

--------------------


### removeMarker(...)

```typescript
removeMarker(options: { id: string; markerId: string; }) => Promise<void>
```

Remove a single marker by id. Convenience over {@link removeMarkers}.

| Param         | Type                                           |
| ------------- | ---------------------------------------------- |
| **`options`** | <code>{ id: string; markerId: string; }</code> |

--------------------


### enableClustering(...)

```typescript
enableClustering(options: { id: string; }) => Promise<void>
```

| Param         | Type                         |
| ------------- | ---------------------------- |
| **`options`** | <code>{ id: string; }</code> |

--------------------


### disableClustering(...)

```typescript
disableClustering(options: { id: string; }) => Promise<void>
```

| Param         | Type                         |
| ------------- | ---------------------------- |
| **`options`** | <code>{ id: string; }</code> |

--------------------


### addPolylines(...)

```typescript
addPolylines(options: { id: string; polylines: Polyline[]; }) => Promise<{ ids: string[]; }>
```

| Param         | Type                                                |
| ------------- | --------------------------------------------------- |
| **`options`** | <code>{ id: string; polylines: Polyline[]; }</code> |

**Returns:** <code>Promise&lt;{ ids: string[]; }&gt;</code>

--------------------


### addPolygons(...)

```typescript
addPolygons(options: { id: string; polygons: Polygon[]; }) => Promise<{ ids: string[]; }>
```

| Param         | Type                                              |
| ------------- | ------------------------------------------------- |
| **`options`** | <code>{ id: string; polygons: Polygon[]; }</code> |

**Returns:** <code>Promise&lt;{ ids: string[]; }&gt;</code>

--------------------


### addCircles(...)

```typescript
addCircles(options: { id: string; circles: Circle[]; }) => Promise<{ ids: string[]; }>
```

| Param         | Type                                            |
| ------------- | ----------------------------------------------- |
| **`options`** | <code>{ id: string; circles: Circle[]; }</code> |

**Returns:** <code>Promise&lt;{ ids: string[]; }&gt;</code>

--------------------


### removeOverlays(...)

```typescript
removeOverlays(options: { id: string; ids: string[]; }) => Promise<void>
```

Remove overlays (polylines, polygons, or circles) by the ids their add call returned.

| Param         | Type                                        |
| ------------- | ------------------------------------------- |
| **`options`** | <code>{ id: string; ids: string[]; }</code> |

--------------------


### setMapType(...)

```typescript
setMapType(options: { id: string; mapType: MapType; }) => Promise<void>
```

Set the base map imagery.

| Param         | Type                                                                  |
| ------------- | --------------------------------------------------------------------- |
| **`options`** | <code>{ id: string; mapType: <a href="#maptype">MapType</a>; }</code> |

--------------------


### enableCurrentLocation(...)

```typescript
enableCurrentLocation(options: { id: string; enabled: boolean; }) => Promise<void>
```

Show or hide the blue user-location dot. The host app is responsible for the
`NSLocationWhenInUseUsageDescription` Info.plist key and for prompting the
user for location permission; without it MapKit shows nothing.

| Param         | Type                                           |
| ------------- | ---------------------------------------------- |
| **`options`** | <code>{ id: string; enabled: boolean; }</code> |

--------------------


### setTrafficEnabled(...)

```typescript
setTrafficEnabled(options: { id: string; enabled: boolean; }) => Promise<void>
```

Overlay or hide live traffic conditions (`MKMapView.showsTraffic`).

| Param         | Type                                           |
| ------------- | ---------------------------------------------- |
| **`options`** | <code>{ id: string; enabled: boolean; }</code> |

--------------------


### setPointsOfInterestEnabled(...)

```typescript
setPointsOfInterestEnabled(options: { id: string; enabled: boolean; }) => Promise<void>
```

Show or hide Apple's points of interest (a `.includingAll` / `.excludingAll` filter).

| Param         | Type                                           |
| ------------- | ---------------------------------------------- |
| **`options`** | <code>{ id: string; enabled: boolean; }</code> |

--------------------


### setCompassEnabled(...)

```typescript
setCompassEnabled(options: { id: string; enabled: boolean; }) => Promise<void>
```

Show or hide the compass (`MKMapView.showsCompass`).

| Param         | Type                                           |
| ------------- | ---------------------------------------------- |
| **`options`** | <code>{ id: string; enabled: boolean; }</code> |

--------------------


### setScaleEnabled(...)

```typescript
setScaleEnabled(options: { id: string; enabled: boolean; }) => Promise<void>
```

Show or hide the scale bar (`MKMapView.showsScale`).

| Param         | Type                                           |
| ------------- | ---------------------------------------------- |
| **`options`** | <code>{ id: string; enabled: boolean; }</code> |

--------------------


### setColorScheme(...)

```typescript
setColorScheme(options: { id: string; colorScheme: MapColorScheme; }) => Promise<void>
```

Force a light/dark appearance, or `default` to follow the device setting.

| Param         | Type                                                                                    |
| ------------- | --------------------------------------------------------------------------------------- |
| **`options`** | <code>{ id: string; colorScheme: <a href="#mapcolorscheme">MapColorScheme</a>; }</code> |

--------------------


### searchAutocomplete(...)

```typescript
searchAutocomplete(options: { query: string; region?: SearchRegion; }) => Promise<{ results: SearchCompletion[]; }>
```

Type-ahead place autocomplete via `MKLocalSearchCompleter`. Needs no API
key. Pass `region` to bias suggestions toward the area in view. Each result
carries an opaque `id`; pass it to {@link searchResolve} to get coordinates.

| Param         | Type                                                                               |
| ------------- | ---------------------------------------------------------------------------------- |
| **`options`** | <code>{ query: string; region?: <a href="#searchregion">SearchRegion</a>; }</code> |

**Returns:** <code>Promise&lt;{ results: SearchCompletion[]; }&gt;</code>

--------------------


### searchPlaces(...)

```typescript
searchPlaces(options: { query: string; region?: SearchRegion; maxDistanceKm?: number; limit?: number; }) => Promise<{ results: SearchResult[]; }>
```

One-shot place search via `MKLocalSearch`. Unlike {@link searchAutocomplete}
the results carry coordinates up front. Pass `region` to scope/bias results,
`maxDistanceKm` to drop results farther than that from the region center
(e.g. a US ZIP that also exists abroad), and `limit` to cap the count.

| Param         | Type                                                                                                                       |
| ------------- | -------------------------------------------------------------------------------------------------------------------------- |
| **`options`** | <code>{ query: string; region?: <a href="#searchregion">SearchRegion</a>; maxDistanceKm?: number; limit?: number; }</code> |

**Returns:** <code>Promise&lt;{ results: SearchResult[]; }&gt;</code>

--------------------


### searchResolve(...)

```typescript
searchResolve(options: { id: string; }) => Promise<{ lat?: number; lng?: number; title?: string; }>
```

Resolve a suggestion `id` (from either search method) to coordinates.
Returns an empty object if the id is unknown or has no location.

| Param         | Type                         |
| ------------- | ---------------------------- |
| **`options`** | <code>{ id: string; }</code> |

**Returns:** <code>Promise&lt;{ lat?: number; lng?: number; title?: string; }&gt;</code>

--------------------


### onResize(...)

```typescript
onResize(options: { id: string; mapBounds: MapBounds; }) => Promise<void>
```

Keep the native frame in sync as the element resizes.

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code>{ id: string; mapBounds: <a href="#mapbounds">MapBounds</a>; }</code> |

--------------------


### onDisplay(...)

```typescript
onDisplay(options: { id: string; mapBounds: MapBounds; }) => Promise<void>
```

Re-mount the native view after the element becomes visible again.

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code>{ id: string; mapBounds: <a href="#mapbounds">MapBounds</a>; }</code> |

--------------------


### onScroll(...)

```typescript
onScroll(options: { id: string; mapBounds: MapBounds; }) => Promise<void>
```

Keep the native frame in sync as the page scrolls (no-op on iOS).

| Param         | Type                                                                        |
| ------------- | --------------------------------------------------------------------------- |
| **`options`** | <code>{ id: string; mapBounds: <a href="#mapbounds">MapBounds</a>; }</code> |

--------------------


### addListener('onCameraIdle', ...)

```typescript
addListener(eventName: 'onCameraIdle', listenerFunc: (data: CameraIdleCallbackData) => void) => Promise<PluginListenerHandle>
```

| Param              | Type                                                                                         |
| ------------------ | -------------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'onCameraIdle'</code>                                                                  |
| **`listenerFunc`** | <code>(data: <a href="#cameraidlecallbackdata">CameraIdleCallbackData</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('onMarkerClick', ...)

```typescript
addListener(eventName: 'onMarkerClick', listenerFunc: (data: MarkerClickCallbackData) => void) => Promise<PluginListenerHandle>
```

| Param              | Type                                                                                           |
| ------------------ | ---------------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'onMarkerClick'</code>                                                                   |
| **`listenerFunc`** | <code>(data: <a href="#markerclickcallbackdata">MarkerClickCallbackData</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('onMapReady', ...)

```typescript
addListener(eventName: 'onMapReady', listenerFunc: (data: MapReadyCallbackData) => void) => Promise<PluginListenerHandle>
```

| Param              | Type                                                                                     |
| ------------------ | ---------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'onMapReady'</code>                                                                |
| **`listenerFunc`** | <code>(data: <a href="#mapreadycallbackdata">MapReadyCallbackData</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('onMapClick', ...)

```typescript
addListener(eventName: 'onMapClick', listenerFunc: (data: MapClickCallbackData) => void) => Promise<PluginListenerHandle>
```

| Param              | Type                                                                                     |
| ------------------ | ---------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'onMapClick'</code>                                                                |
| **`listenerFunc`** | <code>(data: <a href="#mapclickcallbackdata">MapClickCallbackData</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('onMapLongClick', ...)

```typescript
addListener(eventName: 'onMapLongClick', listenerFunc: (data: MapLongClickCallbackData) => void) => Promise<PluginListenerHandle>
```

| Param              | Type                                                                                     |
| ------------------ | ---------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'onMapLongClick'</code>                                                            |
| **`listenerFunc`** | <code>(data: <a href="#mapclickcallbackdata">MapClickCallbackData</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('onClusterClick', ...)

```typescript
addListener(eventName: 'onClusterClick', listenerFunc: (data: ClusterClickCallbackData) => void) => Promise<PluginListenerHandle>
```

| Param              | Type                                                                                             |
| ------------------ | ------------------------------------------------------------------------------------------------ |
| **`eventName`**    | <code>'onClusterClick'</code>                                                                    |
| **`listenerFunc`** | <code>(data: <a href="#clusterclickcallbackdata">ClusterClickCallbackData</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('onCameraMoveStarted', ...)

```typescript
addListener(eventName: 'onCameraMoveStarted', listenerFunc: (data: CameraMoveStartedCallbackData) => void) => Promise<PluginListenerHandle>
```

| Param              | Type                                                                                                       |
| ------------------ | ---------------------------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'onCameraMoveStarted'</code>                                                                         |
| **`listenerFunc`** | <code>(data: <a href="#cameramovestartedcallbackdata">CameraMoveStartedCallbackData</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('onMarkerDragStart', ...)

```typescript
addListener(eventName: 'onMarkerDragStart', listenerFunc: (data: MarkerDragCallbackData) => void) => Promise<PluginListenerHandle>
```

| Param              | Type                                                                                         |
| ------------------ | -------------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'onMarkerDragStart'</code>                                                             |
| **`listenerFunc`** | <code>(data: <a href="#markerdragcallbackdata">MarkerDragCallbackData</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('onMarkerDrag', ...)

```typescript
addListener(eventName: 'onMarkerDrag', listenerFunc: (data: MarkerDragCallbackData) => void) => Promise<PluginListenerHandle>
```

| Param              | Type                                                                                         |
| ------------------ | -------------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'onMarkerDrag'</code>                                                                  |
| **`listenerFunc`** | <code>(data: <a href="#markerdragcallbackdata">MarkerDragCallbackData</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### addListener('onMarkerDragEnd', ...)

```typescript
addListener(eventName: 'onMarkerDragEnd', listenerFunc: (data: MarkerDragCallbackData) => void) => Promise<PluginListenerHandle>
```

| Param              | Type                                                                                         |
| ------------------ | -------------------------------------------------------------------------------------------- |
| **`eventName`**    | <code>'onMarkerDragEnd'</code>                                                               |
| **`listenerFunc`** | <code>(data: <a href="#markerdragcallbackdata">MarkerDragCallbackData</a>) =&gt; void</code> |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

--------------------


### Interfaces


#### AppleMapConfig

Initial map configuration. The `width`/`height`/`x`/`y`/`devicePixelRatio`
fields are populated by the {@link AppleMap} wrapper from the bound element's
bounding rectangle - callers do not set them.

| Prop                        | Type                                                      | Description                                                                                                                                                                                                                                                                      |
| --------------------------- | --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`center`**                | <code><a href="#latlng">LatLng</a></code>                 |                                                                                                                                                                                                                                                                                  |
| **`zoom`**                  | <code>number</code>                                       | Google-style zoom (0 = whole world). Converted to an MKCoordinateRegion span natively.                                                                                                                                                                                           |
| **`minZoom`**               | <code>number</code>                                       | Hard zoom-out floor. Programmatic and gesture moves are clamped to this.                                                                                                                                                                                                         |
| **`maxZoom`**               | <code>number</code>                                       |                                                                                                                                                                                                                                                                                  |
| **`clustering`**            | <code>boolean</code>                                      | Start with clustering enabled, so markers added later cluster on their first render instead of briefly appearing as individual pins. Equivalent to calling {@link AppleMap.enableClustering} before any {@link AppleMap.addMarkers}, but without the flash. Defaults to `false`. |
| **`mapType`**               | <code><a href="#maptype">MapType</a></code>               | Base map imagery. Defaults to `standard`.                                                                                                                                                                                                                                        |
| **`showInfoWindows`**       | <code>boolean</code>                                      | Show MapKit's native callout bubble (title + optional snippet) when a marker with a `title` is tapped. Defaults to `false`, which preserves the tap-only behavior (`onMarkerClick` fires and the pin deselects immediately).                                                     |
| **`showsTraffic`**          | <code>boolean</code>                                      | Overlay live traffic conditions (`MKMapView.showsTraffic`). Defaults to `false`.                                                                                                                                                                                                 |
| **`showsPointsOfInterest`** | <code>boolean</code>                                      | Show Apple's points of interest (shops, parks, …). Maps to a `MKPointOfInterestFilter` of `.includingAll` / `.excludingAll`. Defaults to `true` (MapKit's default).                                                                                                              |
| **`showsCompass`**          | <code>boolean</code>                                      | Show the compass when the map is rotated (`MKMapView.showsCompass`). Defaults to `true`.                                                                                                                                                                                         |
| **`showsScale`**            | <code>boolean</code>                                      | Show the scale bar while zooming (`MKMapView.showsScale`). Defaults to `false`.                                                                                                                                                                                                  |
| **`colorScheme`**           | <code><a href="#mapcolorscheme">MapColorScheme</a></code> | Force a light/dark appearance regardless of the device setting. Defaults to `default` (follow system).                                                                                                                                                                           |
| **`width`**                 | <code>number</code>                                       |                                                                                                                                                                                                                                                                                  |
| **`height`**                | <code>number</code>                                       |                                                                                                                                                                                                                                                                                  |
| **`x`**                     | <code>number</code>                                       |                                                                                                                                                                                                                                                                                  |
| **`y`**                     | <code>number</code>                                       |                                                                                                                                                                                                                                                                                  |
| **`devicePixelRatio`**      | <code>number</code>                                       |                                                                                                                                                                                                                                                                                  |


#### LatLng

A geographic coordinate. Field names match `@capacitor/google-maps` so the
two plugins can sit behind one abstraction in the host app.

| Prop      | Type                |
| --------- | ------------------- |
| **`lat`** | <code>number</code> |
| **`lng`** | <code>number</code> |


#### CameraConfig

| Prop             | Type                                      | Description                                                                        |
| ---------------- | ----------------------------------------- | ---------------------------------------------------------------------------------- |
| **`coordinate`** | <code><a href="#latlng">LatLng</a></code> |                                                                                    |
| **`zoom`**       | <code>number</code>                       |                                                                                    |
| **`animate`**    | <code>boolean</code>                      | Animate the camera move. Defaults to `false` to match the host app's expectations. |


#### LatLngBounds

Visible-region bounds, mirroring the `@capacitor/google-maps` shape.

| Prop            | Type                                      |
| --------------- | ----------------------------------------- |
| **`southwest`** | <code><a href="#latlng">LatLng</a></code> |
| **`center`**    | <code><a href="#latlng">LatLng</a></code> |
| **`northeast`** | <code><a href="#latlng">LatLng</a></code> |


#### CameraPosition

The map's current camera, returned by {@link CapacitorAppleMapsPlugin.getCameraPosition}.

| Prop            | Type                                                  | Description                                             |
| --------------- | ----------------------------------------------------- | ------------------------------------------------------- |
| **`latitude`**  | <code>number</code>                                   |                                                         |
| **`longitude`** | <code>number</code>                                   |                                                         |
| **`zoom`**      | <code>number</code>                                   | Google-style zoom derived from the current region span. |
| **`bounds`**    | <code><a href="#latlngbounds">LatLngBounds</a></code> |                                                         |


#### Marker

| Prop             | Type                                            | Description                                                                                                                                                                                                                                                                                    |
| ---------------- | ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`coordinate`** | <code><a href="#latlng">LatLng</a></code>       |                                                                                                                                                                                                                                                                                                |
| **`title`**      | <code>string</code>                             |                                                                                                                                                                                                                                                                                                |
| **`snippet`**    | <code>string</code>                             | Secondary line shown under `title` in the native callout (see `showInfoWindows`).                                                                                                                                                                                                              |
| **`iconUrl`**    | <code>string</code>                             | Bundled asset filename (e.g. `marker-blue.png`, resolved from `public/`), an `https:` URL, or a `data:` URI. SVG is not supported by MapKit. Omit it to get MapKit's native default pin.                                                                                                       |
| **`iconSize`**   | <code>{ width: number; height: number; }</code> | Logical size in points.                                                                                                                                                                                                                                                                        |
| **`markerId`**   | <code>string</code>                             | Caller-supplied stable id. When set it is used verbatim (and echoed back from {@link CapacitorAppleMapsPlugin.addMarkers} and on tap) instead of a generated one, so the host can map pins back to its own domain objects and target them with {@link CapacitorAppleMapsPlugin.updateMarkers}. |
| **`draggable`**  | <code>boolean</code>                            | Let the user drag this pin (press-and-hold, then move). Fires `onMarkerDragStart` / `onMarkerDrag` / `onMarkerDragEnd`. Defaults to `false`. A pin that is currently clustered can't be dragged until it separates into its own annotation.                                                    |


#### MarkerUpdate

A partial change to an existing marker, addressed by its `markerId`. Omitted
fields are left as-is; a moved marker animates to its new coordinate.

| Prop             | Type                                            | Description                                 |
| ---------------- | ----------------------------------------------- | ------------------------------------------- |
| **`markerId`**   | <code>string</code>                             |                                             |
| **`coordinate`** | <code><a href="#latlng">LatLng</a></code>       |                                             |
| **`title`**      | <code>string</code>                             |                                             |
| **`snippet`**    | <code>string</code>                             |                                             |
| **`iconUrl`**    | <code>string</code>                             |                                             |
| **`iconSize`**   | <code>{ width: number; height: number; }</code> |                                             |
| **`draggable`**  | <code>boolean</code>                            | Enable or disable dragging for this marker. |


#### Polyline

Shared stroke/fill styling for overlays. Colors are `#RRGGBB` or `#RRGGBBAA` hex.

| Prop                | Type                  | Description                                                        |
| ------------------- | --------------------- | ------------------------------------------------------------------ |
| **`path`**          | <code>LatLng[]</code> |                                                                    |
| **`strokeColor`**   | <code>string</code>   | Line color hex. Defaults to the system blue.                       |
| **`strokeWeight`**  | <code>number</code>   | Line width in points. Defaults to `3`.                             |
| **`strokeOpacity`** | <code>number</code>   | Line opacity `0..1`, applied on top of any alpha in `strokeColor`. |


#### Polygon

| Prop                | Type                                | Description                                                                                                  |
| ------------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| **`paths`**         | <code>LatLng[] \| LatLng[][]</code> | Either a single ring of points, or an array of rings where the first is the exterior and the rest are holes. |
| **`strokeColor`**   | <code>string</code>                 |                                                                                                              |
| **`strokeWeight`**  | <code>number</code>                 |                                                                                                              |
| **`strokeOpacity`** | <code>number</code>                 |                                                                                                              |
| **`fillColor`**     | <code>string</code>                 | Fill color hex. Unfilled if omitted.                                                                         |
| **`fillOpacity`**   | <code>number</code>                 |                                                                                                              |


#### Circle

| Prop                | Type                                      | Description       |
| ------------------- | ----------------------------------------- | ----------------- |
| **`center`**        | <code><a href="#latlng">LatLng</a></code> |                   |
| **`radius`**        | <code>number</code>                       | Radius in meters. |
| **`strokeColor`**   | <code>string</code>                       |                   |
| **`strokeWeight`**  | <code>number</code>                       |                   |
| **`strokeOpacity`** | <code>number</code>                       |                   |
| **`fillColor`**     | <code>string</code>                       |                   |
| **`fillOpacity`**   | <code>number</code>                       |                   |


#### SearchCompletion

One type-ahead suggestion from `searchAutocomplete`.

| Prop           | Type                | Description                                        |
| -------------- | ------------------- | -------------------------------------------------- |
| **`id`**       | <code>string</code> | Opaque id to pass to `searchResolve`.              |
| **`title`**    | <code>string</code> | Primary line, e.g. a street address or place name. |
| **`subtitle`** | <code>string</code> | Secondary line, e.g. the city/region.              |


#### SearchRegion

Region to bias autocomplete toward - pass the map's current center so results
favour the area in view. Deltas default to 1° if omitted.

| Prop                 | Type                |
| -------------------- | ------------------- |
| **`latitude`**       | <code>number</code> |
| **`longitude`**      | <code>number</code> |
| **`latitudeDelta`**  | <code>number</code> |
| **`longitudeDelta`** | <code>number</code> |


#### SearchResult

One coordinate-bearing result from `searchPlaces`.

| Prop            | Type                | Description                                                             |
| --------------- | ------------------- | ----------------------------------------------------------------------- |
| **`id`**        | <code>string</code> | Opaque id to pass to `searchResolve` (or use the coordinates directly). |
| **`title`**     | <code>string</code> |                                                                         |
| **`subtitle`**  | <code>string</code> |                                                                         |
| **`latitude`**  | <code>number</code> |                                                                         |
| **`longitude`** | <code>number</code> |                                                                         |


#### MapBounds

The rectangle the native map should occupy, in CSS pixels.

| Prop         | Type                |
| ------------ | ------------------- |
| **`x`**      | <code>number</code> |
| **`y`**      | <code>number</code> |
| **`width`**  | <code>number</code> |
| **`height`** | <code>number</code> |


#### PluginListenerHandle

| Prop         | Type                                      |
| ------------ | ----------------------------------------- |
| **`remove`** | <code>() =&gt; Promise&lt;void&gt;</code> |


#### CameraIdleCallbackData

| Prop            | Type                                                  |
| --------------- | ----------------------------------------------------- |
| **`mapId`**     | <code>string</code>                                   |
| **`latitude`**  | <code>number</code>                                   |
| **`longitude`** | <code>number</code>                                   |
| **`zoom`**      | <code>number</code>                                   |
| **`bounds`**    | <code><a href="#latlngbounds">LatLngBounds</a></code> |


#### MarkerClickCallbackData

| Prop            | Type                |
| --------------- | ------------------- |
| **`mapId`**     | <code>string</code> |
| **`markerId`**  | <code>string</code> |
| **`latitude`**  | <code>number</code> |
| **`longitude`** | <code>number</code> |
| **`title`**     | <code>string</code> |


#### MapReadyCallbackData

| Prop        | Type                |
| ----------- | ------------------- |
| **`mapId`** | <code>string</code> |


#### MapClickCallbackData

| Prop            | Type                |
| --------------- | ------------------- |
| **`mapId`**     | <code>string</code> |
| **`latitude`**  | <code>number</code> |
| **`longitude`** | <code>number</code> |


#### ClusterClickCallbackData

A tap on a cluster bubble. Carries the members it groups.

| Prop            | Type                  | Description                               |
| --------------- | --------------------- | ----------------------------------------- |
| **`mapId`**     | <code>string</code>   |                                           |
| **`latitude`**  | <code>number</code>   |                                           |
| **`longitude`** | <code>number</code>   |                                           |
| **`count`**     | <code>number</code>   | Number of markers in the cluster.         |
| **`markerIds`** | <code>string[]</code> | The `markerId`s of the clustered markers. |


#### CameraMoveStartedCallbackData

Fired once when the camera begins moving, before `onCameraIdle`. `isGesture`
distinguishes a user pan/zoom/rotate from a programmatic move (a
{@link CapacitorAppleMapsPlugin.setCamera} / {@link CapacitorAppleMapsPlugin.fitBounds}
call). Mirrors `@capacitor/google-maps`'s `onCameraMoveStarted`.

| Prop            | Type                 | Description                                                        |
| --------------- | -------------------- | ------------------------------------------------------------------ |
| **`mapId`**     | <code>string</code>  |                                                                    |
| **`isGesture`** | <code>boolean</code> | `true` for a user gesture, `false` for a programmatic camera move. |


#### MarkerDragCallbackData

A drag on a `draggable` marker, carrying the marker's live coordinate.
`onMarkerDragStart` fires once when the drag begins, `onMarkerDrag` fires
continuously as it moves, and `onMarkerDragEnd` fires once on release.

| Prop            | Type                |
| --------------- | ------------------- |
| **`mapId`**     | <code>string</code> |
| **`markerId`**  | <code>string</code> |
| **`latitude`**  | <code>number</code> |
| **`longitude`** | <code>number</code> |


### Type Aliases


#### MapType

Base map imagery. Maps to `MKMapType`; the `*Flyover` variants render 3D
satellite imagery where Apple has it. Defaults to `standard`.

<code>'standard' | 'satellite' | 'hybrid' | 'satelliteFlyover' | 'hybridFlyover' | 'mutedStandard'</code>


#### MapColorScheme

Forces the map's light/dark appearance regardless of the device setting, via
`overrideUserInterfaceStyle`. `default` follows the system.

<code>'default' | 'light' | 'dark'</code>


#### MapLongClickCallbackData

A long-press on the map surface (not on a marker).

<code><a href="#mapclickcallbackdata">MapClickCallbackData</a></code>

</docgen-api>

## Maintainers

| Maintainer    | GitHub                                    | Active |
| ------------- | ----------------------------------------- | ------ |
| pjaudiomv | [pjaudiomv](https://github.com/pjaudiomv) | yes    |

## Contributors

Thanks goes to these wonderful people
([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/pjaudiomv"><img src="https://avatars.githubusercontent.com/u/pjaudiomv?s=100" width="100px;" alt="pjaudiomv"/><br /><sub><b>pjaudiomv</b></sub></a><br /><a href="https://github.com/katamaengineering/capacitor-plugin-apple-maps/commits?author=pjaudiomv" title="Code">💻</a> <a href="https://github.com/katamaengineering/capacitor-plugin-apple-maps/commits?author=pjaudiomv" title="Documentation">📖</a> <a href="#maintenance-pjaudiomv" title="Maintenance">🚧</a> <a href="https://github.com/katamaengineering/capacitor-plugin-apple-maps/commits?author=pjaudiomv" title="Tests">⚠️</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the
[all-contributors](https://github.com/all-contributors/all-contributors)
specification. Contributions of any kind are welcome!

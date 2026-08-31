# capacitor-plugin-apple-maps

Renders a **native Apple Maps (MapKit)** view on iOS from a Capacitor app. The
`AppleMap` wrapper class deliberately mirrors the subset of
[`@capacitor/google-maps`](https://github.com/ionic-team/capacitor-plugins/tree/main/google-maps)'
`GoogleMap` API that a meeting/venue finder needs — create, camera, markers,
clustering, and camera-idle / marker-click events — so an app can route **iOS to
Apple Maps and Android/web to Google Maps** behind one thin abstraction.

- **iOS only.** MapKit is a native iOS framework and needs no API key. On web
  and Android every method rejects with `unavailable` — the host app is expected
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

Marker icons resolve from three sources: a **bundled web asset** filename
(copied into the app bundle under `public/` — e.g. `marker-blue.png` from your
web `static/`), an **`https:` URL**, or a **`data:` URI**. SVG is not supported.

### Sharing one abstraction with `@capacitor/google-maps`

The wrapper's method names and payload shapes (`LatLng`, `LatLngBounds`,
`CameraIdleCallbackData`, `MarkerClickCallbackData`) match `@capacitor/google-maps`,
so a host app can pick the provider per platform:

```ts
const map = Capacitor.getPlatform() === 'ios'
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
* [`addMarkers(...)`](#addmarkers)
* [`removeMarkers(...)`](#removemarkers)
* [`enableClustering(...)`](#enableclustering)
* [`disableClustering(...)`](#disableclustering)
* [`searchAutocomplete(...)`](#searchautocomplete)
* [`searchResolve(...)`](#searchresolve)
* [`onResize(...)`](#onresize)
* [`onDisplay(...)`](#ondisplay)
* [`onScroll(...)`](#onscroll)
* [`addListener('onCameraIdle', ...)`](#addlisteneroncameraidle-)
* [`addListener('onMarkerClick', ...)`](#addlisteneronmarkerclick-)
* [`addListener('onMapReady', ...)`](#addlisteneronmapready-)
* [Interfaces](#interfaces)

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


### addMarkers(...)

```typescript
addMarkers(options: { id: string; markers: Marker[]; }) => Promise<{ ids: string[]; }>
```

| Param         | Type                                            |
| ------------- | ----------------------------------------------- |
| **`options`** | <code>{ id: string; markers: Marker[]; }</code> |

**Returns:** <code>Promise&lt;{ ids: string[]; }&gt;</code>

--------------------


### removeMarkers(...)

```typescript
removeMarkers(options: { id: string; markerIds: string[]; }) => Promise<void>
```

| Param         | Type                                              |
| ------------- | ------------------------------------------------- |
| **`options`** | <code>{ id: string; markerIds: string[]; }</code> |

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


### searchAutocomplete(...)

```typescript
searchAutocomplete(options: { query: string; }) => Promise<{ results: SearchCompletion[]; }>
```

Native place autocomplete via `MKLocalSearchCompleter`. Needs no API key.
Each result carries an opaque `id`; pass it to {@link searchResolve} to get
coordinates.

| Param         | Type                            |
| ------------- | ------------------------------- |
| **`options`** | <code>{ query: string; }</code> |

**Returns:** <code>Promise&lt;{ results: SearchCompletion[]; }&gt;</code>

--------------------


### searchResolve(...)

```typescript
searchResolve(options: { id: string; }) => Promise<{ lat?: number; lng?: number; title?: string; }>
```

Resolve an autocomplete result `id` to coordinates via `MKLocalSearch`.
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


### Interfaces


#### AppleMapConfig

Initial map configuration. The `width`/`height`/`x`/`y`/`devicePixelRatio`
fields are populated by the {@link AppleMap} wrapper from the bound element's
bounding rectangle — callers do not set them.

| Prop                   | Type                                      | Description                                                                            |
| ---------------------- | ----------------------------------------- | -------------------------------------------------------------------------------------- |
| **`center`**           | <code><a href="#latlng">LatLng</a></code> |                                                                                        |
| **`zoom`**             | <code>number</code>                       | Google-style zoom (0 = whole world). Converted to an MKCoordinateRegion span natively. |
| **`minZoom`**          | <code>number</code>                       | Hard zoom-out floor. Programmatic and gesture moves are clamped to this.               |
| **`maxZoom`**          | <code>number</code>                       |                                                                                        |
| **`width`**            | <code>number</code>                       |                                                                                        |
| **`height`**           | <code>number</code>                       |                                                                                        |
| **`x`**                | <code>number</code>                       |                                                                                        |
| **`y`**                | <code>number</code>                       |                                                                                        |
| **`devicePixelRatio`** | <code>number</code>                       |                                                                                        |


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


#### Marker

| Prop             | Type                                            | Description                                                                                                                                  |
| ---------------- | ----------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| **`coordinate`** | <code><a href="#latlng">LatLng</a></code>       |                                                                                                                                              |
| **`title`**      | <code>string</code>                             |                                                                                                                                              |
| **`iconUrl`**    | <code>string</code>                             | Bundled asset filename (e.g. `marker-blue.png`, resolved from `public/`), an `https:` URL, or a `data:` URI. SVG is not supported by MapKit. |
| **`iconSize`**   | <code>{ width: number; height: number; }</code> | Logical size in points.                                                                                                                      |


#### SearchCompletion

One native autocomplete suggestion.

| Prop           | Type                | Description                                        |
| -------------- | ------------------- | -------------------------------------------------- |
| **`id`**       | <code>string</code> | Opaque id to pass to `searchResolve`.              |
| **`title`**    | <code>string</code> | Primary line, e.g. a street address or place name. |
| **`subtitle`** | <code>string</code> | Secondary line, e.g. the city/region.              |


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

</docgen-api>

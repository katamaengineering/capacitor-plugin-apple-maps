import type { PluginListenerHandle } from '@capacitor/core';

/**
 * A geographic coordinate. Field names match `@capacitor/google-maps` so the
 * two plugins can sit behind one abstraction in the host app.
 */
export interface LatLng {
  lat: number;
  lng: number;
}

/**
 * Initial map configuration. The `width`/`height`/`x`/`y`/`devicePixelRatio`
 * fields are populated by the {@link AppleMap} wrapper from the bound element's
 * bounding rectangle - callers do not set them.
 */
export interface AppleMapConfig {
  center: LatLng;
  /** Google-style zoom (0 = whole world). Converted to an MKCoordinateRegion span natively. */
  zoom: number;
  /** Hard zoom-out floor. Programmatic and gesture moves are clamped to this. */
  minZoom?: number;
  maxZoom?: number;
  // --- Populated by the wrapper, not by callers. ---
  width?: number;
  height?: number;
  x?: number;
  y?: number;
  devicePixelRatio?: number;
}

export interface CameraConfig {
  coordinate?: LatLng;
  zoom?: number;
  /** Animate the camera move. Defaults to `false` to match the host app's expectations. */
  animate?: boolean;
}

export interface Marker {
  coordinate: LatLng;
  title?: string;
  /**
   * Bundled asset filename (e.g. `marker-blue.png`, resolved from `public/`),
   * an `https:` URL, or a `data:` URI. SVG is not supported by MapKit. Omit it
   * to get MapKit's native default pin.
   */
  iconUrl?: string;
  /** Logical size in points. */
  iconSize?: { width: number; height: number };
}

/** Visible-region bounds, mirroring the `@capacitor/google-maps` shape. */
export interface LatLngBounds {
  southwest: LatLng;
  center: LatLng;
  northeast: LatLng;
}

/** The rectangle the native map should occupy, in CSS pixels. */
export interface MapBounds {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface CameraIdleCallbackData {
  mapId: string;
  latitude: number;
  longitude: number;
  zoom: number;
  bounds: LatLngBounds;
}

export interface MarkerClickCallbackData {
  mapId: string;
  markerId: string;
  latitude: number;
  longitude: number;
  title?: string;
}

export interface MapReadyCallbackData {
  mapId: string;
}

/** One type-ahead suggestion from `searchAutocomplete`. */
export interface SearchCompletion {
  /** Opaque id to pass to `searchResolve`. */
  id: string;
  /** Primary line, e.g. a street address or place name. */
  title: string;
  /** Secondary line, e.g. the city/region. */
  subtitle: string;
}

/** One coordinate-bearing result from `searchPlaces`. */
export interface SearchResult {
  /** Opaque id to pass to `searchResolve` (or use the coordinates directly). */
  id: string;
  title: string;
  subtitle: string;
  latitude: number;
  longitude: number;
}

/**
 * Region to bias autocomplete toward - pass the map's current center so results
 * favour the area in view. Deltas default to 1° if omitted.
 */
export interface SearchRegion {
  latitude: number;
  longitude: number;
  latitudeDelta?: number;
  longitudeDelta?: number;
}

/**
 * Low-level bridge to the native MapKit implementation. Most callers should use
 * the {@link AppleMap} wrapper instead of these methods directly.
 */
export interface CapacitorAppleMapsPlugin {
  create(options: { id: string; config: AppleMapConfig; element?: unknown; forceCreate?: boolean }): Promise<void>;
  destroy(options: { id: string }): Promise<void>;
  setCamera(options: { id: string; config: CameraConfig }): Promise<void>;
  getMapBounds(options: { id: string }): Promise<LatLngBounds>;
  addMarkers(options: { id: string; markers: Marker[] }): Promise<{ ids: string[] }>;
  removeMarkers(options: { id: string; markerIds: string[] }): Promise<void>;
  enableClustering(options: { id: string }): Promise<void>;
  disableClustering(options: { id: string }): Promise<void>;

  /**
   * Type-ahead place autocomplete via `MKLocalSearchCompleter`. Needs no API
   * key. Pass `region` to bias suggestions toward the area in view. Each result
   * carries an opaque `id`; pass it to {@link searchResolve} to get coordinates.
   */
  searchAutocomplete(options: { query: string; region?: SearchRegion }): Promise<{ results: SearchCompletion[] }>;
  /**
   * One-shot place search via `MKLocalSearch`. Unlike {@link searchAutocomplete}
   * the results carry coordinates up front. Pass `region` to scope/bias results,
   * `maxDistanceKm` to drop results farther than that from the region center
   * (e.g. a US ZIP that also exists abroad), and `limit` to cap the count.
   */
  searchPlaces(options: {
    query: string;
    region?: SearchRegion;
    maxDistanceKm?: number;
    limit?: number;
  }): Promise<{ results: SearchResult[] }>;
  /**
   * Resolve a suggestion `id` (from either search method) to coordinates.
   * Returns an empty object if the id is unknown or has no location.
   */
  searchResolve(options: { id: string }): Promise<{ lat?: number; lng?: number; title?: string }>;

  /** Keep the native frame in sync as the element resizes. */
  onResize(options: { id: string; mapBounds: MapBounds }): Promise<void>;
  /** Re-mount the native view after the element becomes visible again. */
  onDisplay(options: { id: string; mapBounds: MapBounds }): Promise<void>;
  /** Keep the native frame in sync as the page scrolls (no-op on iOS). */
  onScroll(options: { id: string; mapBounds: MapBounds }): Promise<void>;

  addListener(
    eventName: 'onCameraIdle',
    listenerFunc: (data: CameraIdleCallbackData) => void,
  ): Promise<PluginListenerHandle>;
  addListener(
    eventName: 'onMarkerClick',
    listenerFunc: (data: MarkerClickCallbackData) => void,
  ): Promise<PluginListenerHandle>;
  addListener(
    eventName: 'onMapReady',
    listenerFunc: (data: MapReadyCallbackData) => void,
  ): Promise<PluginListenerHandle>;
}

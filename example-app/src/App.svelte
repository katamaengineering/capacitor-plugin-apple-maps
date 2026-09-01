<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { Capacitor } from '@capacitor/core';
  import { AppleMap } from 'capacitor-plugin-apple-maps';
  import { GoogleMap } from '@capacitor/google-maps';

  // ── The only platform branch in the whole app ────────────────────────────
  // Both plugins expose the same create/addMarkers/listeners API, so the app
  // picks a provider once and never branches again. Apple Maps needs no key;
  // Google Maps needs one on Android (AndroidManifest) and web (below).
  const isIOS = Capacitor.getPlatform() === 'ios';
  const googleKey = import.meta.env.VITE_GOOGLE_MAPS_API_KEY ?? '';

  // On Android/web a missing key would crash Google Maps natively (nothing JS
  // can catch), so show a hint instead of creating the map.
  const needsKey = !isIOS && !googleKey;
  const provider = isIOS ? 'Apple Maps (MapKit)' : 'Google Maps';

  const center = { lat: 37.7749, lng: -122.4194 }; // San Francisco
  const markers = [
    { markerId: 'sf', coordinate: center, title: 'San Francisco', snippet: 'City Hall area' },
    { markerId: 'ggb', coordinate: { lat: 37.8199, lng: -122.4783 }, title: 'Golden Gate Bridge', snippet: '1937' },
    {
      markerId: 'wharf',
      coordinate: { lat: 37.8087, lng: -122.4098 },
      title: "Fisherman's Wharf",
      snippet: 'Pier 39 · drag me',
      // Press-and-hold, then drag, to move this pin (iOS). Zoom in first if it's
      // clustered with the others. Both plugins accept the `draggable` field.
      draggable: true,
    },
    {
      // A standalone pin, placed well south of the SF trio so it never clusters
      // (a lone pin always renders individually) — tap it and its info window
      // (native callout) pops up. Requires `showInfoWindows: true` on the map.
      markerId: 'info-demo',
      coordinate: { lat: 37.6213, lng: -122.379 },
      title: 'Tap me',
      snippet: 'This is an info window',
    },
  ];

  let element = $state<HTMLElement>();
  // Shared handle used by the platform-agnostic paths (create/destroy/markers).
  let map: AppleMap | GoogleMap | undefined;
  // Apple-only handle, assigned only on iOS, so the new MapKit-only calls
  // type-check without casting the shared union everywhere.
  let appleMap: AppleMap | undefined;
  let note = $state('');

  // Results of the iOS smoke sequence, rendered as a ✓/✗ checklist.
  let steps = $state<{ name: string; ok: boolean; detail: string }[]>([]);
  // Overlay ids returned by the smoke sequence, so "Clear overlays" can undo them.
  let overlayIds = $state<string[]>([]);
  // Tracks the current base map type; the toggle label reflects the *next* action.
  let satellite = $state(false);
  // Appearance-toggle state, so each button's label reflects the *next* action.
  let traffic = $state(false);
  let dark = $state(false);

  // Android draws the Google map BEHIND the webview and shows it through a
  // transparent element, so every layer above the map must be see-through or you
  // just see the page background. iOS/web render the map into the element itself.
  const isAndroid = Capacitor.getPlatform() === 'android';

  const errMsg = (err: unknown) => (err instanceof Error ? err.message : String(err));

  // A bounds box around the 3 markers: southwest = min lat/lng, northeast =
  // max lat/lng, center = the average. Used by fitBounds when no live bounds
  // are handy.
  function markerBounds() {
    const lats = markers.map((m) => m.coordinate.lat);
    const lngs = markers.map((m) => m.coordinate.lng);
    const south = Math.min(...lats);
    const north = Math.max(...lats);
    const west = Math.min(...lngs);
    const east = Math.max(...lngs);
    return {
      southwest: { lat: south, lng: west },
      northeast: { lat: north, lng: east },
      center: { lat: (south + north) / 2, lng: (west + east) / 2 },
    };
  }

  // Run one named smoke step, recording ✓ + detail or ✗ + error into `steps`.
  async function step(name: string, run: () => Promise<string>) {
    try {
      const detail = await run();
      steps = [...steps, { name, ok: true, detail }];
    } catch (err) {
      steps = [...steps, { name, ok: false, detail: errMsg(err) }];
    }
  }

  // The actual camera move, shared by the smoke sequence (which records a step)
  // and the "Fit bounds" button (which reports via `note`, so repeated taps
  // don't pollute the one-shot smoke checklist).
  async function applyFitBounds() {
    if (!appleMap) return;
    await appleMap.fitBounds(markerBounds(), 48, true);
  }

  async function fitBoundsButton() {
    try {
      await applyFitBounds();
      note = 'fit bounds';
    } catch (err) {
      note = `fitBounds failed: ${errMsg(err)}`;
    }
  }

  // The automatic iOS-only exercise: touch each new AppleMap method once and
  // report the outcome, keeping any overlay ids for later cleanup.
  async function runSmokeSequence(am: AppleMap) {
    await step('getCameraPosition', async () => {
      const pos = await am.getCameraPosition();
      return `zoom ${pos.zoom.toFixed(1)}`;
    });

    await step('addPolylines', async () => {
      const ids = await am.addPolylines([
        { path: markers.map((m) => m.coordinate), strokeColor: '#2563eb', strokeWeight: 4, strokeOpacity: 0.9 },
      ]);
      overlayIds = [...overlayIds, ...ids];
      return `${ids.length} id${ids.length === 1 ? '' : 's'}`;
    });

    await step('addPolygons', async () => {
      const ids = await am.addPolygons([
        {
          paths: markers.map((m) => m.coordinate),
          strokeColor: '#2563eb',
          strokeWeight: 2,
          fillColor: '#3b82f6',
          fillOpacity: 0.2,
        },
      ]);
      overlayIds = [...overlayIds, ...ids];
      return `${ids.length} id${ids.length === 1 ? '' : 's'}`;
    });

    await step('addCircles', async () => {
      const ids = await am.addCircles([
        { center, radius: 1500, strokeColor: '#2563eb', fillColor: '#3b82f6', fillOpacity: 0.2 },
      ]);
      overlayIds = [...overlayIds, ...ids];
      return `${ids.length} id${ids.length === 1 ? '' : 's'}`;
    });

    await step('fitBounds', async () => {
      // Exercise the coordinate-array overload: pass the raw pins and let the
      // wrapper compute the bounding box.
      await am.fitBounds(
        markers.map((m) => m.coordinate),
        48,
        true,
      );
      return 'ok';
    });

    await step('addMarker + removeMarker', async () => {
      const id = await am.addMarker({
        coordinate: { lat: center.lat - 0.02, lng: center.lng - 0.02 },
        title: 'Temp pin',
      });
      await am.removeMarker(id);
      return `id ${id.slice(0, 8)}…`;
    });

    await step('updateMarkers', async () => {
      await am.updateMarkers([
        { markerId: 'sf', coordinate: { lat: center.lat + 0.01, lng: center.lng }, title: 'San Francisco (moved)' },
      ]);
      return 'ok';
    });

    await step('appearance toggles', async () => {
      // Touch each appearance setter once, then restore the visible defaults so
      // the map looks normal after the smoke run (compass on, POI on, standard
      // color scheme). Scale is left on so the config vs runtime paths differ.
      await am.setTrafficEnabled(true);
      await am.setPointsOfInterestEnabled(false);
      await am.setCompassEnabled(false);
      await am.setScaleEnabled(true);
      await am.setColorScheme('dark');
      await am.setColorScheme('default');
      await am.setCompassEnabled(true);
      await am.setPointsOfInterestEnabled(true);
      await am.setTrafficEnabled(false);
      return 'traffic/POI/compass/scale/colorScheme';
    });

    await step('draggable toggle', async () => {
      // The 'wharf' pin is draggable from create; toggle it off and back on via
      // updateMarkers to exercise that path. Actual dragging needs a real touch,
      // so the on-device tester drags the pin and watches the `note` line.
      await am.updateMarkers([{ markerId: 'wharf', draggable: false }]);
      await am.updateMarkers([{ markerId: 'wharf', draggable: true }]);
      return 'wharf drag-and-drop ready';
    });

    await step('gestures + padding', async () => {
      // Disable rotate/pitch, keep pan+zoom, and inset the map so the controls
      // clear the header; then restore full gestures.
      await am.setGestures({ rotate: false, pitch: false });
      await am.setPadding({ top: 8, left: 8, right: 8, bottom: 8 });
      await am.setGestures({ scroll: true, zoom: true, rotate: true, pitch: true });
      return 'ok';
    });

    await step('takeSnapshot', async () => {
      const image = await am.takeSnapshot();
      return image.startsWith('data:image/png;base64,') ? `${Math.round(image.length / 1024)} KB` : 'unexpected';
    });
  }

  // ── iOS control-bar actions ──────────────────────────────────────────────
  async function toggleMapType() {
    if (!appleMap) return;
    try {
      await appleMap.setMapType(satellite ? 'standard' : 'hybrid');
      satellite = !satellite;
      note = satellite ? 'satellite view' : 'standard view';
    } catch (err) {
      note = `setMapType failed: ${errMsg(err)}`;
    }
  }

  async function clearOverlays() {
    if (!appleMap || overlayIds.length === 0) return;
    try {
      await appleMap.removeOverlays(overlayIds);
      note = `cleared ${overlayIds.length} overlays`;
      overlayIds = [];
    } catch (err) {
      note = `removeOverlays failed: ${errMsg(err)}`;
    }
  }

  async function myLocation() {
    if (!appleMap) return;
    try {
      // Harmless without permission; to actually show the blue dot the app's
      // Info.plist needs NSLocationWhenInUseUsageDescription.
      await appleMap.enableCurrentLocation(true);
      note = 'current location enabled';
    } catch (err) {
      note = `enableCurrentLocation failed: ${errMsg(err)}`;
    }
  }

  async function toggleTraffic() {
    if (!appleMap) return;
    try {
      await appleMap.setTrafficEnabled(!traffic);
      traffic = !traffic;
      note = traffic ? 'traffic on' : 'traffic off';
    } catch (err) {
      note = `setTrafficEnabled failed: ${errMsg(err)}`;
    }
  }

  async function toggleColorScheme() {
    if (!appleMap) return;
    try {
      await appleMap.setColorScheme(dark ? 'default' : 'dark');
      dark = !dark;
      note = dark ? 'dark map' : 'system map';
    } catch (err) {
      note = `setColorScheme failed: ${errMsg(err)}`;
    }
  }

  onMount(async () => {
    if (isAndroid) document.documentElement.classList.add('android-underlay');
    if (needsKey || !element) return;
    try {
      // create() waits for the element's layout internally, so there's nothing
      // to poll for here. forceCreate rebuilds the native view for this id
      // rather than reusing a stale one from a previous mount.
      if (isIOS) {
        appleMap = await AppleMap.create({
          id: 'map',
          element,
          config: {
            center,
            zoom: 11,
            minZoom: 3,
            maxZoom: 18,
            clustering: true,
            showInfoWindows: true,
            // Exercise the create-time appearance path (the runtime setters are
            // covered by the smoke sequence and the control-bar buttons).
            showsScale: true,
          },
          forceCreate: true,
        });
        map = appleMap;

        // No iconUrl needed — each provider draws its own default pin.
        await appleMap.addMarkers(markers);

        // Report every gesture through the single `note` string.
        await appleMap.setOnMarkerClickListener((data) => {
          note = `tapped ${data.title || data.markerId}`;
        });
        await appleMap.setOnInfoWindowClickListener((data) => {
          note = `info window tapped: ${data.title || data.markerId}`;
        });
        await appleMap.setOnMapClickListener((data) => {
          note = `map click @ ${data.latitude.toFixed(3)},${data.longitude.toFixed(3)}`;
        });
        await appleMap.setOnMapLongClickListener((data) => {
          note = `long-press @ ${data.latitude.toFixed(3)},${data.longitude.toFixed(3)}`;
        });
        await appleMap.setOnClusterClickListener((data) => {
          note = `cluster ×${data.count}`;
        });
        await appleMap.setOnCameraMoveStartedListener((data) => {
          note = data.isGesture ? 'camera move (gesture)' : 'camera move (programmatic)';
        });

        // Draggable-marker events (the 'wharf' pin opted in via `draggable`).
        await appleMap.setOnMarkerDragStartListener((data) => {
          note = `drag start ${data.markerId}`;
        });
        await appleMap.setOnMarkerDragListener((data) => {
          note = `dragging @ ${data.latitude.toFixed(3)},${data.longitude.toFixed(3)}`;
        });
        await appleMap.setOnMarkerDragEndListener((data) => {
          note = `drag end @ ${data.latitude.toFixed(3)},${data.longitude.toFixed(3)}`;
        });

        // Kick off the automatic smoke sequence.
        await runSmokeSequence(appleMap);
      } else {
        map = await GoogleMap.create({ id: 'map', element, apiKey: googleKey, config: { center, zoom: 11 }, forceCreate: true });

        // No iconUrl needed — each provider draws its own default pin.
        await map.addMarkers(markers);
        await map.setOnMarkerClickListener((data) => {
          note = `tapped ${data.title || data.markerId}`;
        });
      }
    } catch (err) {
      note = `map error: ${errMsg(err)}`;
    }
  });

  onDestroy(() => {
    void map?.destroy();
  });
</script>

<div class="app">
  <header>
    <h1>capacitor-plugin-apple-maps</h1>
    <p><strong>{provider}</strong>{note ? ` · ${note}` : ''}</p>
  </header>

  {#if needsKey}
    <div class="notice">
      <p>Set <code>VITE_GOOGLE_MAPS_API_KEY</code> (and the AndroidManifest key) to show Google Maps.</p>
      <p>iOS needs no key — run it there to see Apple Maps.</p>
    </div>
  {:else if isIOS}
    <div class="map-wrap">
      <capacitor-apple-map bind:this={element} id="map" class="map"></capacitor-apple-map>

      <!-- iOS-only control bar: every button calls the plugin and reports via `note`. -->
      <div class="controls">
        <button onclick={toggleMapType}>{satellite ? 'Standard' : 'Satellite'}</button>
        <button onclick={toggleTraffic}>{traffic ? 'Traffic off' : 'Traffic'}</button>
        <button onclick={toggleColorScheme}>{dark ? 'System' : 'Dark'}</button>
        <button onclick={fitBoundsButton}>Fit bounds</button>
        <button onclick={clearOverlays} disabled={overlayIds.length === 0}>Clear overlays</button>
        <button onclick={myLocation}>My location</button>
      </div>

      <!-- Smoke-test checklist + latest gesture note, translucent over the map. -->
      <div class="panel">
        <ul class="steps">
          {#each steps as s, i (i)}
            <li class:fail={!s.ok}>
              <span class="mark">{s.ok ? '✓' : '✗'}</span>
              <span class="step-name">{s.name}</span>
              <span class="detail">{s.detail}</span>
            </li>
          {/each}
        </ul>
        {#if note}
          <p class="note">{note}</p>
        {/if}
      </div>
    </div>
  {:else}
    <capacitor-google-map bind:this={element} id="map" class="map"></capacitor-google-map>
  {/if}
</div>

<style>
  :global(html, body) {
    margin: 0;
    height: 100%;
    background: #0b1020;
  }
  /* Android renders the Google map behind the webview — the page above it must
     be transparent for the map to show through. */
  :global(html.android-underlay),
  :global(html.android-underlay body) {
    background: transparent;
  }
  .app {
    display: flex;
    flex-direction: column;
    height: 100dvh;
    font-family:
      -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  }
  header {
    padding: max(env(safe-area-inset-top), 14px) 16px 12px;
    color: #fff;
    background: #405ec9;
  }
  h1 {
    margin: 0;
    font-size: 17px;
    font-weight: 700;
    letter-spacing: -0.01em;
  }
  header p {
    margin: 2px 0 0;
    font-size: 13px;
    opacity: 0.9;
  }
  /* Holds the map plus the iOS overlays; the map still fills all of it. */
  .map-wrap {
    position: relative;
    flex: 1;
    display: flex;
  }
  .map {
    flex: 1;
    display: block;
    width: 100%;
  }
  .controls {
    position: absolute;
    top: 12px;
    left: 12px;
    right: 12px;
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    z-index: 2;
  }
  .controls button {
    padding: 8px 12px;
    font-size: 13px;
    font-weight: 600;
    color: #eaf0ff;
    background: rgba(20, 30, 62, 0.82);
    border: 1px solid rgba(120, 150, 230, 0.5);
    border-radius: 999px;
    backdrop-filter: blur(6px);
    -webkit-backdrop-filter: blur(6px);
    cursor: pointer;
  }
  .controls button:active {
    background: rgba(64, 94, 201, 0.9);
  }
  .controls button:disabled {
    opacity: 0.4;
    cursor: default;
  }
  .panel {
    position: absolute;
    left: 12px;
    right: 12px;
    bottom: max(env(safe-area-inset-bottom), 12px);
    max-height: 42%;
    overflow-y: auto;
    padding: 10px 12px;
    color: #dbe4ff;
    background: rgba(11, 16, 32, 0.78);
    border: 1px solid rgba(120, 150, 230, 0.35);
    border-radius: 12px;
    backdrop-filter: blur(8px);
    -webkit-backdrop-filter: blur(8px);
    z-index: 2;
  }
  .steps {
    margin: 0;
    padding: 0;
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .steps li {
    display: flex;
    align-items: baseline;
    gap: 8px;
    font-size: 13px;
  }
  .mark {
    color: #4ade80;
    font-weight: 700;
  }
  .steps li.fail .mark {
    color: #f87171;
  }
  .step-name {
    font-weight: 600;
  }
  .detail {
    margin-left: auto;
    opacity: 0.75;
    font-variant-numeric: tabular-nums;
  }
  .note {
    margin: 8px 0 0;
    padding-top: 8px;
    border-top: 1px solid rgba(120, 150, 230, 0.25);
    font-size: 13px;
    color: #aab8e6;
  }
  .notice {
    flex: 1;
    display: flex;
    flex-direction: column;
    justify-content: center;
    gap: 10px;
    padding: 0 28px;
    color: #c7d0e8;
    font-size: 15px;
    line-height: 1.5;
    text-align: center;
  }
  .notice code {
    color: #fff;
    font-size: 13px;
  }
</style>

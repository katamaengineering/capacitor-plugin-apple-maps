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
    { coordinate: center, title: 'San Francisco' },
    { coordinate: { lat: 37.8199, lng: -122.4783 }, title: 'Golden Gate Bridge' },
    { coordinate: { lat: 37.8087, lng: -122.4098 }, title: "Fisherman's Wharf" },
  ];

  let element = $state<HTMLElement>();
  let map: AppleMap | GoogleMap | undefined;
  let note = $state('');

  // Android draws the Google map BEHIND the webview and shows it through a
  // transparent element, so every layer above the map must be see-through or you
  // just see the page background. iOS/web render the map into the element itself.
  const isAndroid = Capacitor.getPlatform() === 'android';

  onMount(async () => {
    if (isAndroid) document.documentElement.classList.add('android-underlay');
    if (needsKey || !element) return;
    try {
      // create() waits for the element's layout internally, so there's nothing
      // to poll for here. forceCreate rebuilds the native view for this id
      // rather than reusing a stale one from a previous mount.
      map = isIOS
        ? await AppleMap.create({ id: 'map', element, config: { center, zoom: 11 }, forceCreate: true })
        : await GoogleMap.create({ id: 'map', element, apiKey: googleKey, config: { center, zoom: 11 }, forceCreate: true });

      // No iconUrl needed — each provider draws its own default pin.
      await map.addMarkers(markers);
      await map.setOnMarkerClickListener((data) => {
        note = `tapped ${data.title || data.markerId}`;
      });
    } catch (err) {
      note = `map error: ${err instanceof Error ? err.message : String(err)}`;
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
    <capacitor-apple-map bind:this={element} id="map" class="map"></capacitor-apple-map>
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
  .map {
    flex: 1;
    display: block;
    width: 100%;
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

# Example: Apple Maps + Google Maps, one API

A deliberately tiny [Svelte](https://svelte.dev) + Capacitor app showing the
whole point of this plugin: **iOS renders Apple Maps (MapKit), Android and web
render Google Maps, from one shared API.**

The entire app is [`src/App.svelte`](src/App.svelte). The only place it branches
on platform is picking the provider — after that, `create`, `addMarkers`, and
the listeners are identical:

```ts
const isIOS = Capacitor.getPlatform() === 'ios';

map = isIOS
  ? await AppleMap.create({ id: 'map', element, config: { center, zoom: 11 } })
  : await GoogleMap.create({ id: 'map', element, apiKey: googleKey, config: { center, zoom: 11 } });

await map.addMarkers([{ coordinate: center, title: 'San Francisco' }]);
await map.setOnMarkerClickListener((data) => (tapped = data.title ?? data.markerId));
```

The markers pass **no `iconUrl`** — each provider draws its own default pin
(Apple Maps does this as of plugin 0.3.2).

The markers also pass **no `iconUrl`** — each provider draws its own default pin
(Apple Maps does this as of plugin 0.3.2).

## Run it

```bash
npm install
```

### iOS — Apple Maps, no API key needed

```bash
npm run sim:ios                              # build + boot a simulator (picker)
npm run targets:ios                          # list simulators + IDs
npm run sim:ios -- --target <simulator-id>   # boot a specific one
npm run ios                                  # build + open Xcode
```

### Android / web — Google Maps, needs a key

Google Maps needs an API key (enable *Maps SDK for Android* and *Maps JavaScript
API* for it). Without one the app shows a hint instead of a map — it never
crashes. Set the **same key** in two places:

1. **Web + the on/off signal** — copy `.env.example` to `.env` and set
   `VITE_GOOGLE_MAPS_API_KEY`.
2. **Android native** — set `MAPS_API_KEY` in `android/gradle.properties` (or
   `~/.gradle/gradle.properties`). It fills the `com.google.android.geo.API_KEY`
   placeholder already wired into the manifest.

```bash
npm start                                        # web dev server
npm run sim:android                              # build + boot the emulator
npm run sim:android -- --target <emulator-id>    # a specific one (targets:android to list)
npm run android                                  # build + open Android Studio
```

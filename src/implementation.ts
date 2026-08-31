import { registerPlugin } from '@capacitor/core';

import type { CapacitorAppleMapsPlugin } from './definitions';

/**
 * The registered plugin proxy. On iOS this bridges to the native MapKit
 * implementation; on web and Android every method rejects with `unavailable`
 * (the host app is expected to route those platforms to a different provider).
 */
export const CapacitorAppleMaps = registerPlugin<CapacitorAppleMapsPlugin>('CapacitorAppleMaps', {
  web: () => import('./web').then((m) => new m.CapacitorAppleMapsWeb()),
});

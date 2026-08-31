import { registerPlugin } from '@capacitor/core';

import type { CapacitorAppleMapsPlugin } from './definitions';

const CapacitorAppleMaps = registerPlugin<CapacitorAppleMapsPlugin>('CapacitorAppleMaps', {
  web: () => import('./web').then((m) => new m.CapacitorAppleMapsWeb()),
});

export * from './definitions';
export { CapacitorAppleMaps };

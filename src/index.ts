import type { SearchCompletion, SearchRegion } from './definitions';
import { CapacitorAppleMaps } from './implementation';

export * from './definitions';
export { CapacitorAppleMaps } from './implementation';
export { AppleMap } from './map';
export type { CreateMapArgs } from './map';

/**
 * Native place autocomplete (iOS, `MKLocalSearchCompleter`). No API key needed.
 * Returns suggestions keyed by an opaque id; resolve one with {@link searchResolve}.
 */
export function searchAutocomplete(options: {
  query: string;
  region?: SearchRegion;
}): Promise<{ results: SearchCompletion[] }> {
  return CapacitorAppleMaps.searchAutocomplete(options);
}

/** Resolve an autocomplete result id to coordinates (iOS, `MKLocalSearch`). */
export function searchResolve(options: { id: string }): Promise<{ lat?: number; lng?: number; title?: string }> {
  return CapacitorAppleMaps.searchResolve(options);
}

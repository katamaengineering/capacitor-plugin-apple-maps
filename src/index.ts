import type { SearchCompletion, SearchRegion, SearchResult } from './definitions';
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

/**
 * One-shot native place search (iOS, `MKLocalSearch`). Results carry
 * coordinates; supports region scoping, a distance filter, and a result limit.
 */
export function searchPlaces(options: {
  query: string;
  region?: SearchRegion;
  maxDistanceKm?: number;
  limit?: number;
}): Promise<{ results: SearchResult[] }> {
  return CapacitorAppleMaps.searchPlaces(options);
}

/** Resolve a suggestion id (from either search method) to coordinates (iOS). */
export function searchResolve(options: { id: string }): Promise<{ lat?: number; lng?: number; title?: string }> {
  return CapacitorAppleMaps.searchResolve(options);
}

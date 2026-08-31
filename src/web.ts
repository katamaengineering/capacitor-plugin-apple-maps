import { WebPlugin } from '@capacitor/core';

import type { CapacitorAppleMapsPlugin, LatLngBounds } from './definitions';

/**
 * Web fallback. Apple Maps is a native MapKit feature with no web surface here,
 * so every method rejects with `unavailable`. The host app should route web
 * (and Android) to another map provider rather than calling this plugin.
 */
export class CapacitorAppleMapsWeb extends WebPlugin implements CapacitorAppleMapsPlugin {
  private notAvailable(): never {
    throw this.unavailable('Apple Maps is only available on iOS.');
  }

  async create(): Promise<void> {
    this.notAvailable();
  }

  async destroy(): Promise<void> {
    this.notAvailable();
  }

  async setCamera(): Promise<void> {
    this.notAvailable();
  }

  async getMapBounds(): Promise<LatLngBounds> {
    this.notAvailable();
  }

  async addMarkers(): Promise<{ ids: string[] }> {
    this.notAvailable();
  }

  async removeMarkers(): Promise<void> {
    this.notAvailable();
  }

  async enableClustering(): Promise<void> {
    this.notAvailable();
  }

  async disableClustering(): Promise<void> {
    this.notAvailable();
  }

  async searchAutocomplete(): Promise<{ results: never[] }> {
    this.notAvailable();
  }

  async searchPlaces(): Promise<{ results: never[] }> {
    this.notAvailable();
  }

  async searchResolve(): Promise<{ lat?: number; lng?: number; title?: string }> {
    this.notAvailable();
  }

  async onResize(): Promise<void> {
    this.notAvailable();
  }

  async onDisplay(): Promise<void> {
    this.notAvailable();
  }

  async onScroll(): Promise<void> {
    this.notAvailable();
  }
}

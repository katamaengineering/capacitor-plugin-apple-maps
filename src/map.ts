import { Capacitor } from '@capacitor/core';
import type { PluginListenerHandle } from '@capacitor/core';

import type {
  AppleMapConfig,
  CameraConfig,
  CameraIdleCallbackData,
  LatLngBounds,
  MapReadyCallbackData,
  Marker,
  MarkerClickCallbackData,
} from './definitions';
import { CapacitorAppleMaps } from './implementation';

export interface CreateMapArgs {
  /** Unique id for this map instance. */
  id: string;
  /** The `<capacitor-apple-map>` (or any) element the native map is bound to. */
  element: HTMLElement;
  config: AppleMapConfig;
  /** Destroy and recreate if a map with this id already exists. */
  forceCreate?: boolean;
}

/**
 * Custom element the native map mounts into. On iOS it is given a scrollable
 * inner box so WKWebView materialises a child scroll view at the element's
 * dimensions — the native MapKit view is inserted into that subview. This is
 * the same compositing trick `@capacitor/google-maps` uses.
 */
class MapCustomElement extends HTMLElement {
  connectedCallback(): void {
    this.innerHTML = '';
    if (Capacitor.getPlatform() === 'ios') {
      this.style.overflow = 'scroll';
      (this.style as unknown as Record<string, string>)['-webkit-overflow-scrolling'] = 'touch';
      const overflowDiv = document.createElement('div');
      overflowDiv.style.height = '200%';
      this.appendChild(overflowDiv);
    }
  }
}

if (typeof customElements !== 'undefined' && !customElements.get('capacitor-apple-map')) {
  customElements.define('capacitor-apple-map', MapCustomElement);
}

/**
 * High-level handle to a native Apple Map. Create one with {@link AppleMap.create};
 * the API deliberately mirrors the subset of `@capacitor/google-maps`'s
 * `GoogleMap` that the host app relies on, so the two can share one abstraction.
 */
export class AppleMap {
  private id: string;
  private element: HTMLElement | null = null;
  private resizeObserver: ResizeObserver | null = null;
  private handleScrollEvent = (): void => this.updateMapBounds();

  private onCameraIdleListener?: PluginListenerHandle;
  private onMarkerClickListener?: PluginListenerHandle;

  private constructor(id: string) {
    this.id = id;
  }

  static async create(options: CreateMapArgs): Promise<AppleMap> {
    const newMap = new AppleMap(options.id);

    if (!options.element) {
      throw new Error('container element is required');
    }

    newMap.element = options.element;
    newMap.element.dataset.internalId = options.id;

    const bounds = await AppleMap.getElementBounds(options.element);
    options.config.width = bounds.width;
    options.config.height = bounds.height;
    options.config.x = bounds.x;
    options.config.y = bounds.y;
    options.config.devicePixelRatio = window.devicePixelRatio;

    if (Capacitor.isNativePlatform()) {
      // Keep the native frame synced as the element resizes or is re-shown.
      const getMapBounds = () => {
        const rect = newMap.element?.getBoundingClientRect() ?? ({} as DOMRect);
        return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
      };
      const onResize = () => CapacitorAppleMaps.onResize({ id: newMap.id, mapBounds: getMapBounds() });
      const onDisplay = () => CapacitorAppleMaps.onDisplay({ id: newMap.id, mapBounds: getMapBounds() });

      const lastState = { width: bounds.width, height: bounds.height, isHidden: false };
      newMap.resizeObserver = new ResizeObserver(() => {
        if (newMap.element == null) return;
        const rect = newMap.element.getBoundingClientRect();
        const isHidden = rect.width === 0 && rect.height === 0;
        if (!isHidden) {
          if (lastState.isHidden) {
            onDisplay();
          } else if (lastState.width !== rect.width || lastState.height !== rect.height) {
            onResize();
          }
        }
        lastState.width = rect.width;
        lastState.height = rect.height;
        lastState.isHidden = isHidden;
      });
      newMap.resizeObserver.observe(newMap.element);

      window.addEventListener('scroll', newMap.handleScrollEvent);
      window.addEventListener('resize', newMap.handleScrollEvent);
    }

    // Small delay so iOS WKWebView has set up the element's child scroll view.
    await new Promise<void>((resolve, reject) => {
      setTimeout(async () => {
        try {
          await CapacitorAppleMaps.create({ id: options.id, config: options.config, forceCreate: options.forceCreate });
          resolve();
        } catch (err) {
          reject(err);
        }
      }, 200);
    });

    return newMap;
  }

  private static getElementBounds(element: HTMLElement): Promise<DOMRect> {
    return new Promise((resolve) => {
      let bounds = element.getBoundingClientRect();
      if (bounds.width !== 0) {
        resolve(bounds);
        return;
      }
      let retries = 0;
      const interval = setInterval(() => {
        bounds = element.getBoundingClientRect();
        if (bounds.width !== 0 || retries >= 30) {
          if (retries >= 30) console.warn('AppleMap: element size could not be determined');
          clearInterval(interval);
          resolve(bounds);
        }
        retries++;
      }, 100);
    });
  }

  private updateMapBounds(): void {
    if (!this.element) return;
    const rect = this.element.getBoundingClientRect();
    CapacitorAppleMaps.onScroll({
      id: this.id,
      mapBounds: { x: rect.x, y: rect.y, width: rect.width, height: rect.height },
    });
  }

  async setCamera(config: CameraConfig): Promise<void> {
    return CapacitorAppleMaps.setCamera({ id: this.id, config });
  }

  async getMapBounds(): Promise<LatLngBounds> {
    return CapacitorAppleMaps.getMapBounds({ id: this.id });
  }

  async addMarkers(markers: Marker[]): Promise<string[]> {
    const res = await CapacitorAppleMaps.addMarkers({ id: this.id, markers });
    return res.ids;
  }

  async removeMarkers(ids: string[]): Promise<void> {
    return CapacitorAppleMaps.removeMarkers({ id: this.id, markerIds: ids });
  }

  async enableClustering(): Promise<void> {
    return CapacitorAppleMaps.enableClustering({ id: this.id });
  }

  async disableClustering(): Promise<void> {
    return CapacitorAppleMaps.disableClustering({ id: this.id });
  }

  async setOnCameraIdleListener(callback?: (data: CameraIdleCallbackData) => void): Promise<void> {
    if (this.onCameraIdleListener) {
      await this.onCameraIdleListener.remove();
      this.onCameraIdleListener = undefined;
    }
    if (callback) {
      this.onCameraIdleListener = await CapacitorAppleMaps.addListener('onCameraIdle', (data) => {
        if (data.mapId === this.id) callback(data);
      });
    }
  }

  async setOnMarkerClickListener(callback?: (data: MarkerClickCallbackData) => void): Promise<void> {
    if (this.onMarkerClickListener) {
      await this.onMarkerClickListener.remove();
      this.onMarkerClickListener = undefined;
    }
    if (callback) {
      this.onMarkerClickListener = await CapacitorAppleMaps.addListener('onMarkerClick', (data) => {
        if (data.mapId === this.id) callback(data);
      });
    }
  }

  async setOnMapReadyListener(callback?: (data: MapReadyCallbackData) => void): Promise<void> {
    if (callback) {
      const handle = await CapacitorAppleMaps.addListener('onMapReady', (data) => {
        if (data.mapId === this.id) callback(data);
      });
      // One-shot; caller does not need the handle.
      void handle;
    }
  }

  async destroy(): Promise<void> {
    if (Capacitor.isNativePlatform()) {
      window.removeEventListener('scroll', this.handleScrollEvent);
      window.removeEventListener('resize', this.handleScrollEvent);
    }
    this.resizeObserver?.disconnect();
    this.resizeObserver = null;
    await this.onCameraIdleListener?.remove();
    await this.onMarkerClickListener?.remove();
    this.onCameraIdleListener = undefined;
    this.onMarkerClickListener = undefined;
    return CapacitorAppleMaps.destroy({ id: this.id });
  }
}

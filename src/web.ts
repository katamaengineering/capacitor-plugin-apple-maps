import { WebPlugin } from '@capacitor/core';

import type { CapacitorAppleMapsPlugin } from './definitions';

export class CapacitorAppleMapsWeb extends WebPlugin implements CapacitorAppleMapsPlugin {
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}

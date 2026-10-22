import { registerPlugin } from '@capacitor/core';

import type { CapacitorNeonPlugin } from './definitions';

const CapacitorNeon = registerPlugin<CapacitorNeonPlugin>('CapacitorNeon', {
  web: () => import('./web').then((m) => new m.CapacitorNeonWeb()),
});

export * from './definitions';
export { CapacitorNeon };

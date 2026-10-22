import { inject, type InjectionKey } from 'vue';
import type { VitalsStore } from 'illarion-client-core';
export type { VitalsStore } from 'illarion-client-core';
export const vitalsStoreKey: InjectionKey<VitalsStore> = Symbol('vitals-store');

export const useVitalsStore = (): VitalsStore => {
  const store = inject(vitalsStoreKey);
  if (!store) {
    throw new Error('Vitals store was not provided.');
  }
  return store;
};

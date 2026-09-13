import { inject, readonly, ref, type InjectionKey, type Ref } from 'vue';
import type { SeleneUiApi } from '../selene';

export interface VitalsStore {
  readonly health: Readonly<Ref<number>>;
  readonly food: Readonly<Ref<number>>;
  readonly mana: Readonly<Ref<number>>;
}

export const vitalsStoreKey: InjectionKey<VitalsStore> = Symbol('vitals-store');

export const createVitalsStore = (network: SeleneUiApi['network']): VitalsStore => {
  const health = ref(0);
  const food = ref(0);
  const mana = ref(0);

  const subscribe = (payloadId: string, value: Ref<number>) => {
    network.onPayload(payloadId, (payload) => {
      if (typeof payload.value !== 'number' || !Number.isFinite(payload.value)) {
        return;
      }
      value.value = Math.min(1, Math.max(0, payload.value));
    });
  };

  subscribe('illarion:health', health);
  subscribe('illarion:food', food);
  subscribe('illarion:mana', mana);

  return {
    health: readonly(health),
    food: readonly(food),
    mana: readonly(mana),
  };
};

export const useVitalsStore = (): VitalsStore => {
  const store = inject(vitalsStoreKey);
  if (!store) {
    throw new Error('Vitals store was not provided.');
  }
  return store;
};

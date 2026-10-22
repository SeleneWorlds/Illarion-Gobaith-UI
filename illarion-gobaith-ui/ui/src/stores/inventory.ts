import { inject, readonly, ref, watchEffect, type InjectionKey, type Ref } from 'vue';
import { sameInventorySlot, type InventorySlotDefinition } from '../inventory';
import type { Coordinate } from '../selene';
import type { InventoryService } from 'illarion-client-core';
export type { ShowcaseDefinition } from 'illarion-client-core';

export interface InventoryStore extends InventoryService {
  readonly counter: Readonly<Ref<number>>;
  readonly selectedUseSlots: Readonly<Ref<readonly InventorySlotDefinition[]>>;
  setCounter(value: number): void;
  selectUseSlot(viewId: InventorySlotDefinition['viewId'], slotId: number): void;
  finishUse(target?: Coordinate): void;
}
export const inventoryStoreKey: InjectionKey<InventoryStore> = Symbol('inventory-store');

export const createInventoryStore = (inventory: InventoryService): InventoryStore => {
  const counter = ref(1);
  const selectedUseSlots = ref<InventorySlotDefinition[]>([]);
  watchEffect(() => {
    const available = selectedUseSlots.value.filter((slot) => inventory.getItem(slot.viewId, slot.slotId));
    if (available.length !== selectedUseSlots.value.length) {
      selectedUseSlots.value = available;
    }
  });
  return {
    ...inventory,
    counter: readonly(counter),
    selectedUseSlots: readonly(selectedUseSlots),
    setCounter(value) {
      counter.value = Math.min(250, Math.max(1, Math.round(value)));
    },
    selectUseSlot(viewId, slotId) {
      const slot = { viewId, slotId };
      if (!inventory.getItem(viewId, slotId)) {
        return;
      }
      const source = selectedUseSlots.value[0];
      if (!source) {
        selectedUseSlots.value = [slot];
      } else if (!sameInventorySlot(source, slot)) {
        selectedUseSlots.value = [source, slot];
      }
    },
    finishUse(coordinate) {
      const [source, target] = selectedUseSlots.value;
      if (source) {
        inventory.useOn(source, coordinate ?? target, counter.value);
      }
      selectedUseSlots.value = [];
    },
  };
};

export const useInventoryStore = (): InventoryStore => {
  const store = inject(inventoryStoreKey);
  if (!store) {
    throw new Error('Inventory store was not provided.');
  }
  return store;
};

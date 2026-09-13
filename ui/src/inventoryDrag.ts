import type { InjectionKey } from 'vue';
import type { InventoryDragStartDetail } from './inventory';

export interface InventoryDragApi {
  start(detail: InventoryDragStartDetail): void;
}

export const inventoryDragKey: InjectionKey<InventoryDragApi> = Symbol('inventory-drag');

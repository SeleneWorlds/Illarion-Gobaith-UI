import type { InjectionKey } from 'vue';
import type { InventoryDragStartDetail, InventoryItem, InventorySlotDefinition } from './inventory';
import type { Coordinate } from './selene';

export interface InventoryDropTarget {
  clientX: number;
  clientY: number;
  acceptSlot(source: InventorySlotDefinition, item: InventoryItem, count: number): void;
  acceptCoordinate?(source: Coordinate, count: number): void;
}

export interface InventoryDragApi {
  start(detail: InventoryDragStartDetail): void;
  releaseOn(target: InventoryDropTarget): void;
}

export const inventoryDragKey: InjectionKey<InventoryDragApi> = Symbol('inventory-drag');

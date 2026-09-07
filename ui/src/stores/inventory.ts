// TODO deslop file
import { inject, reactive, readonly, ref, type InjectionKey, type Ref } from 'vue';
import type { ClientNetworkPayload, Coordinate, SeleneUiApi } from '../selene';
import type { InventoryItem, InventorySlotDefinition, InventoryTooltipResponse } from '../inventory';
import { inventorySlotKey } from '../inventory';

type NetworkApi = SeleneUiApi['network'];

export interface InventoryStore {
  readonly items: Readonly<Record<string, InventoryItem>>;
  readonly tooltipResponse: Readonly<Ref<InventoryTooltipResponse | undefined>>;
  readonly counter: Readonly<Ref<number>>;
  setCounter(value: number): void;
  lookAt(slot: InventorySlotDefinition): void;
  moveSlotToSlot(from: InventorySlotDefinition, to: InventorySlotDefinition, count: number): void;
  moveSlotToCoordinate(from: InventorySlotDefinition, to: Coordinate, count: number): void;
  moveCoordinateToSlot(from: Coordinate, to: InventorySlotDefinition, count: number): void;
  openContainer(slot: InventorySlotDefinition, count: number): void;
  use(slot: InventorySlotDefinition, count?: number): void;
  dropInFront(slot: InventorySlotDefinition, count: number): void;
  dispose(): void;
}

export const inventoryStoreKey: InjectionKey<InventoryStore> = Symbol('inventory-store');

const payloadString = (payload: ClientNetworkPayload, field: string) =>
  typeof payload[field] === 'string' ? payload[field] as string : undefined;
const payloadNumber = (payload: ClientNetworkPayload, field: string) =>
  typeof payload[field] === 'number' && Number.isInteger(payload[field]) ? payload[field] as number : undefined;
const payloadSlot = (payload: ClientNetworkPayload): InventorySlotDefinition | undefined => {
  const viewId = payloadString(payload, 'viewId');
  const slotId = payloadNumber(payload, 'slotId');
  return (viewId === 'equipment' || viewId === 'belt') && slotId !== undefined
    ? { viewId, slotId }
    : undefined;
};

export const createInventoryStore = (network: NetworkApi): InventoryStore => {
  const items = reactive<Record<string, InventoryItem>>({});
  const tooltipResponse = ref<InventoryTooltipResponse>();
  const counter = ref(1);
  let requestedTooltipSlot: InventorySlotDefinition | undefined;

  const updateSlot = (payload: ClientNetworkPayload) => {
    const slot = payloadSlot(payload);
    if (!slot) return;
    const slotKey = inventorySlotKey(slot);
    const item = payload.item;
    const itemPayload = item && typeof item === 'object' ? item as ClientNetworkPayload : undefined;
    const visual = typeof itemPayload?.visual === 'string' ? itemPayload.visual : undefined;
    if (!visual) {
      delete items[slotKey];
      if (requestedTooltipSlot && inventorySlotKey(requestedTooltipSlot) === slotKey) {
        requestedTooltipSlot = undefined;
        tooltipResponse.value = undefined;
      }
      return;
    }
    items[slotKey] = {
      visual,
      count: typeof itemPayload?.count === 'number' ? Math.max(1, Math.round(itemPayload.count)) : 1,
      container: itemPayload?.container === true,
    };
  };

  const updateTooltip = (payload: ClientNetworkPayload) => {
    const slot = payloadSlot(payload);
    if (!slot || !requestedTooltipSlot || inventorySlotKey(slot) !== inventorySlotKey(requestedTooltipSlot)) return;
    const value = payload.tooltip;
    tooltipResponse.value = {
      slot,
      tooltip: value && typeof value === 'object' ? value as InventoryTooltipResponse['tooltip'] : undefined,
    };
  };

  const unsubscribers = [
    network.onPayload('illarion:update_slot', updateSlot),
    network.onPayload('illarion:look_at_slot', updateTooltip),
  ];

  return {
    items: readonly(items),
    tooltipResponse: readonly(tooltipResponse),
    counter: readonly(counter),
    setCounter(value) {
      counter.value = Math.min(250, Math.max(1, Math.round(value)));
    },
    lookAt(slot) {
      requestedTooltipSlot = slot;
      tooltipResponse.value = undefined;
      network.sendToServer('illarion:look_at_slot', { ...slot });
    },
    moveSlotToSlot(from, to, count) {
      network.sendToServer('illarion:move_slot_to_slot', {
        fromViewId: from.viewId, fromSlotId: from.slotId,
        toViewId: to.viewId, toSlotId: to.slotId, count,
      });
    },
    moveSlotToCoordinate(from, to, count) {
      network.sendToServer('illarion:move_slot_to_coordinate', {
        fromViewId: from.viewId, fromSlotId: from.slotId,
        x: to.x, y: to.y, z: to.z, count,
      });
    },
    moveCoordinateToSlot(from, to, count) {
      network.sendToServer('illarion:move_coordinate_to_slot', {
        fromX: from.x, fromY: from.y, fromZ: from.z,
        toViewId: to.viewId, toSlotId: to.slotId, count,
      });
    },
    openContainer(slot, count) {
      network.sendToServer('illarion:open_container_slot', { ...slot, count });
    },
    use(slot, count) {
      network.sendToServer('illarion:use_slot', count === undefined ? { ...slot } : { ...slot, count });
    },
    dropInFront(slot, count) {
      network.sendToServer('illarion:drop_slot_in_front', { ...slot, count });
    },
    dispose() {
      unsubscribers.splice(0).forEach(unsubscribe => unsubscribe());
    },
  };
};

export const useInventoryStore = (): InventoryStore => {
  const store = inject(inventoryStoreKey);
  if (!store) throw new Error('Inventory store was not provided.');
  return store;
};

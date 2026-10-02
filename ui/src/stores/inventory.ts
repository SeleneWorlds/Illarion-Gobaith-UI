import { inject, reactive, readonly, ref, type InjectionKey, type Ref } from 'vue';
import type { ClientNetworkPayload, Coordinate, SeleneUiApi } from '../selene';
import type { InventoryItem, InventorySlotDefinition, InventoryTooltipResponse } from '../inventory';

export interface ShowcaseDefinition {
  id: number;
  slotCount: number;
}

type NetworkApi = SeleneUiApi['network'];

export interface InventoryStore {
  readonly tooltipResponse: Readonly<Ref<InventoryTooltipResponse | undefined>>;
  readonly counter: Readonly<Ref<number>>;
  readonly selectedUseSlots: Readonly<Ref<readonly InventorySlotDefinition[]>>;
  readonly showcases: Readonly<Ref<readonly ShowcaseDefinition[]>>;
  getItem(viewId: InventorySlotDefinition['viewId'], slotId: number): InventoryItem | undefined;
  setCounter(value: number): void;
  lookAt(viewId: InventorySlotDefinition['viewId'], slotId: number): void;
  moveSlotToSlot(
    fromViewId: InventorySlotDefinition['viewId'],
    fromSlotId: number,
    toViewId: InventorySlotDefinition['viewId'],
    toSlotId: number,
    count: number,
  ): void;
  moveSlotToCoordinate(viewId: InventorySlotDefinition['viewId'], slotId: number, to: Coordinate, count: number): void;
  moveCoordinateToSlot(
    from: Coordinate,
    viewId: InventorySlotDefinition['viewId'],
    slotId: number,
    count: number,
  ): void;
  moveCoordinateToCoordinate(from: Coordinate, to: Coordinate, count: number): void;
  openContainer(viewId: InventorySlotDefinition['viewId'], slotId: number, count: number): void;
  closeShowcase(showcaseId: number): void;
  use(viewId: InventorySlotDefinition['viewId'], slotId: number, count?: number): void;
  selectUseSlot(viewId: InventorySlotDefinition['viewId'], slotId: number): void;
  finishUse(): void;
  dropInFront(viewId: InventorySlotDefinition['viewId'], slotId: number, count: number): void;
}

export const inventoryStoreKey: InjectionKey<InventoryStore> = Symbol('inventory-store');

const slotKey = (viewId: InventorySlotDefinition['viewId'], slotId: number) => `${viewId}:${slotId}`;
const sameSlot = (left: InventorySlotDefinition, right: InventorySlotDefinition) =>
  left.viewId === right.viewId && left.slotId === right.slotId;
const payloadSlot = (payload: ClientNetworkPayload): InventorySlotDefinition | undefined => {
  const viewId = payload.viewId;
  const slotId = payload.slotId;
  const validViewId =
    viewId === 'equipment' || viewId === 'belt' || (typeof viewId === 'string' && /^showcase:\d+$/.test(viewId));
  if (!validViewId || typeof slotId !== 'number' || !Number.isInteger(slotId)) {
    return undefined;
  }
  return { viewId: viewId as InventorySlotDefinition['viewId'], slotId };
};

export const createInventoryStore = (network: NetworkApi): InventoryStore => {
  const items = reactive<Record<string, InventoryItem>>({});
  const tooltipResponse = ref<InventoryTooltipResponse>();
  const counter = ref(250);
  const selectedUseSlots = ref<InventorySlotDefinition[]>([]);
  const showcases = ref<ShowcaseDefinition[]>([]);
  let requestedTooltipSlot: InventorySlotDefinition | undefined;

  const removeShowcase = (showcaseId: number) => {
    const viewId = `showcase:${showcaseId}`;
    showcases.value = showcases.value.filter((showcase) => showcase.id !== showcaseId);
    for (const key of Object.keys(items)) {
      if (key.startsWith(`${viewId}:`)) {
        delete items[key];
      }
    }
  };

  const updateSlot = (payload: ClientNetworkPayload) => {
    const slot = payloadSlot(payload);
    if (!slot) {
      return;
    }
    const key = slotKey(slot.viewId, slot.slotId);
    const item = payload.item;
    const itemPayload = item && typeof item === 'object' ? (item as ClientNetworkPayload) : undefined;
    const visual = typeof itemPayload?.visual === 'string' ? itemPayload.visual : undefined;
    if (!visual) {
      delete items[key];
      selectedUseSlots.value = selectedUseSlots.value.filter((selectedSlot) => !sameSlot(selectedSlot, slot));
      if (requestedTooltipSlot && sameSlot(requestedTooltipSlot, slot)) {
        requestedTooltipSlot = undefined;
        tooltipResponse.value = undefined;
      }
      return;
    }
    items[key] = {
      visual,
      count: typeof itemPayload?.count === 'number' ? Math.max(1, Math.round(itemPayload.count)) : 1,
      container: itemPayload?.container === true,
    };
  };

  const updateTooltip = (payload: ClientNetworkPayload) => {
    const slot = payloadSlot(payload);
    if (!slot || !requestedTooltipSlot || !sameSlot(slot, requestedTooltipSlot)) {
      return;
    }
    const value = payload.tooltip;
    tooltipResponse.value = {
      slot,
      tooltip: value && typeof value === 'object' ? (value as InventoryTooltipResponse['tooltip']) : undefined,
    };
  };

  network.onPayload('illarion:update_slot', updateSlot);
  network.onPayload('illarion:look_at_slot', updateTooltip);
  network.onPayload('illarion:close_showcase', (payload) => {
    const showcaseId = payload.showcaseId;
    if (typeof showcaseId === 'number' && Number.isInteger(showcaseId) && showcaseId >= 0) {
      removeShowcase(showcaseId);
    }
  });
  network.onPayload('illarion:showcase', (payload) => {
    const viewId = payload.viewId;
    const slotCount = payload.slotCount;
    const match = typeof viewId === 'string' ? /^showcase:(\d+)$/.exec(viewId) : undefined;
    const showcaseId = match ? Number(match[1]) : undefined;
    if (
      typeof showcaseId !== 'number' ||
      !Number.isInteger(showcaseId) ||
      showcaseId < 0 ||
      typeof slotCount !== 'number' ||
      !Number.isInteger(slotCount) ||
      slotCount < 0
    ) {
      return;
    }
    for (const key of Object.keys(items)) {
      if (key.startsWith(`${viewId}:`)) {
        delete items[key];
      }
    }
    const next = showcases.value.filter((showcase) => showcase.id !== showcaseId);
    next.push({ id: showcaseId, slotCount });
    showcases.value = next.sort((left, right) => left.id - right.id);
  });

  return {
    tooltipResponse: readonly(tooltipResponse),
    counter: readonly(counter),
    selectedUseSlots: readonly(selectedUseSlots),
    showcases: readonly(showcases),
    getItem(viewId, slotId) {
      return items[slotKey(viewId, slotId)];
    },
    setCounter(value) {
      counter.value = Math.min(250, Math.max(1, Math.round(value)));
    },
    lookAt(viewId, slotId) {
      requestedTooltipSlot = { viewId, slotId };
      tooltipResponse.value = undefined;
      network.sendToServer('illarion:look_at_slot', { viewId, slotId });
    },
    moveSlotToSlot(fromViewId, fromSlotId, toViewId, toSlotId, count) {
      network.sendToServer('illarion:move_slot_to_slot', { fromViewId, fromSlotId, toViewId, toSlotId, count });
    },
    moveSlotToCoordinate(viewId, slotId, to, count) {
      network.sendToServer('illarion:move_slot_to_coordinate', {
        fromViewId: viewId,
        fromSlotId: slotId,
        x: to.x,
        y: to.y,
        z: to.z,
        count,
      });
    },
    moveCoordinateToSlot(from, viewId, slotId, count) {
      network.sendToServer('illarion:move_coordinate_to_slot', {
        fromX: from.x,
        fromY: from.y,
        fromZ: from.z,
        toViewId: viewId,
        toSlotId: slotId,
        count,
      });
    },
    moveCoordinateToCoordinate(from, to, count) {
      network.sendToServer('illarion:move_coordinate_to_coordinate', {
        fromX: from.x,
        fromY: from.y,
        fromZ: from.z,
        toX: to.x,
        toY: to.y,
        toZ: to.z,
        count,
      });
    },
    openContainer(viewId, slotId, count) {
      network.sendToServer('illarion:open_container_slot', { viewId, slotId, count });
    },
    closeShowcase(showcaseId) {
      removeShowcase(showcaseId);
      network.sendToServer('illarion:close_showcase', { showcaseId });
    },
    use(viewId, slotId, count) {
      network.sendToServer('illarion:use_slot', count === undefined ? { viewId, slotId } : { viewId, slotId, count });
    },
    selectUseSlot(viewId, slotId) {
      const slot = { viewId, slotId };
      if (
        items[slotKey(viewId, slotId)] &&
        !selectedUseSlots.value.some((selectedSlot) => sameSlot(selectedSlot, slot))
      ) {
        selectedUseSlots.value.push(slot);
      }
    },
    finishUse() {
      for (const slot of selectedUseSlots.value) {
        network.sendToServer('illarion:use_slot', { viewId: slot.viewId, slotId: slot.slotId });
      }
      selectedUseSlots.value = [];
    },
    dropInFront(viewId, slotId, count) {
      network.sendToServer('illarion:drop_slot_in_front', { viewId, slotId, count });
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

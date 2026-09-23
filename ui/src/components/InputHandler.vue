<script setup lang="ts">
import { nextTick, onMounted, onUnmounted, provide, reactive, useTemplateRef } from 'vue';
import { type InventoryDragStartDetail, type InventoryItem, type InventorySlotDefinition } from '../inventory';
import type { Coordinate, SelenePointerEvent } from '../selene';
import { useSelene } from '../selene';
import { inventoryDragKey, type InventoryDropTarget } from '../inventoryDrag';
import { useTooltip } from '../overlays';
import { useInventoryStore } from '../stores/inventory';
import SeleneVisual from './SeleneVisual.vue';

interface InventoryPointer {
  slot: InventorySlotDefinition;
  item: InventoryItem;
  downX: number;
  downY: number;
  dragged: boolean;
}

interface WorldPointer {
  coordinate: Coordinate;
  downX: number;
  downY: number;
  dragged: boolean;
}

interface PendingWorldLookAt {
  coordinate: Coordinate;
  entityId?: number | null;
}

const selene = useSelene();
const inventory = useInventoryStore();
const tooltip = useTooltip();
const previewElement = useTemplateRef<HTMLElement>('previewElement');
const worldTooltipAnchor = useTemplateRef<HTMLElement>('worldTooltipAnchor');
const preview = reactive({
  visual: undefined as string | undefined,
  seed: undefined as string | undefined,
  left: 0,
  top: 0,
});
const worldTooltipPosition = reactive({ left: 0, top: 0 });
let inventoryPointer: InventoryPointer | undefined;
let worldPointer: WorldPointer | undefined;
let pendingWorldLookAt: PendingWorldLookAt | undefined;
let pendingEntityTooltip: { networkId: number; tooltip: unknown } | undefined;
let suppressedClick: { x: number; y: number; button: number } | undefined;
const inputUnsubscribers: Array<() => void> = [];
const networkUnsubscribers: Array<() => void> = [];

const isInWorldViewport = (clientX: number, clientY: number) => {
  const container = worldTooltipAnchor.value?.offsetParent;
  if (!(container instanceof HTMLElement)) {
    return false;
  }
  const rect = container.getBoundingClientRect();
  const x = ((clientX - rect.left) * container.offsetWidth) / rect.width;
  const y = ((clientY - rect.top) * container.offsetHeight) / rect.height;
  return x >= 0 && x < 839 && y >= 0 && y < 419;
};

const updatePreviewPosition = (clientX: number, clientY: number) => {
  const container = previewElement.value?.offsetParent;
  if (!(container instanceof HTMLElement)) {
    return;
  }
  const rect = container.getBoundingClientRect();
  const scale = rect.width / container.offsetWidth;
  preview.left = (clientX - rect.left) / scale;
  preview.top = (clientY - rect.top) / scale;
};

const updateWorldTooltipPosition = (clientX: number, clientY: number) => {
  const container = worldTooltipAnchor.value?.offsetParent;
  if (!(container instanceof HTMLElement)) {
    return;
  }
  const rect = container.getBoundingClientRect();
  const scale = rect.width / container.offsetWidth;
  worldTooltipPosition.left = (clientX - rect.left) / scale;
  worldTooltipPosition.top = (clientY - rect.top) / scale;
};

const showWorldTooltip = (value: unknown) => {
  const anchor = worldTooltipAnchor.value;
  if (!anchor || !value || typeof value !== 'object') {
    return;
  }
  const payload = value as Record<string, unknown>;
  const title = typeof payload.name === 'string' ? payload.name : '';
  const description = typeof payload.description === 'string' ? payload.description : undefined;
  if (!title && !description) {
    return;
  }
  void tooltip.show({ anchor, title, description });
};

const resolvePendingEntityTooltip = () => {
  if (
    pendingWorldLookAt?.entityId !== undefined &&
    pendingWorldLookAt.entityId !== null &&
    pendingEntityTooltip?.networkId === pendingWorldLookAt.entityId
  ) {
    showWorldTooltip(pendingEntityTooltip.tooltip);
    pendingEntityTooltip = undefined;
  }
};

const startInventoryDrag = ({ viewId, slotId, clientX, clientY }: InventoryDragStartDetail) => {
  suppressedClick = undefined;
  const slot = { viewId, slotId };
  const item = inventory.getItem(slot.viewId, slot.slotId);
  if (!item) {
    return;
  }
  inventoryPointer = { slot, item, downX: clientX, downY: clientY, dragged: false };
};

const finishUse = (event: KeyboardEvent) => {
  if (event.key === 'Shift') {
    inventory.finishUse();
  }
};

const onMouseMove = (event: MouseEvent) => {
  if (!inventoryPointer && !worldPointer) {
    return;
  }
  if (inventoryPointer) {
    const wasDragged = inventoryPointer.dragged;
    inventoryPointer.dragged ||=
      Math.abs(event.clientX - inventoryPointer.downX) + Math.abs(event.clientY - inventoryPointer.downY) > 3;
    if (!wasDragged && inventoryPointer.dragged) {
      preview.visual = inventoryPointer.item.visual;
      preview.seed = `${inventoryPointer.slot.viewId}:${inventoryPointer.slot.slotId}`;
      void nextTick(() => updatePreviewPosition(event.clientX, event.clientY));
    }
  }
  if (worldPointer) {
    worldPointer.dragged ||=
      Math.abs(event.clientX - worldPointer.downX) + Math.abs(event.clientY - worldPointer.downY) > 3;
    if (worldPointer.dragged) {
      pendingWorldLookAt = undefined;
      pendingEntityTooltip = undefined;
      tooltip.hide();
    }
  }
  updatePreviewPosition(event.clientX, event.clientY);
};

const onClick = (event: MouseEvent) => {
  const suppressed = suppressedClick;
  suppressedClick = undefined;
  if (
    suppressed &&
    event.button === suppressed.button &&
    event.clientX === suppressed.x &&
    event.clientY === suppressed.y
  ) {
    event.preventDefault();
    event.stopImmediatePropagation();
  }
};

const onPointerDown = ({ button, shiftKey, clientX, clientY, coordinate }: SelenePointerEvent) => {
  if (button === 0 && !shiftKey && isInWorldViewport(clientX, clientY)) {
    tooltip.hide();
    pendingEntityTooltip = undefined;
    pendingWorldLookAt = { coordinate };
    updateWorldTooltipPosition(clientX, clientY);
    worldPointer = { coordinate, downX: clientX, downY: clientY, dragged: false };
    const source = worldPointer;
    void selene.world
      .getEntitiesAt(coordinate)
      .then((entities) => {
        const reversedEntities = [...entities].reverse();
        const lookAtEntity = reversedEntities.find((entity) => entity.tags.includes('illarion:supports_look_at'));
        if (pendingWorldLookAt && pendingWorldLookAt.coordinate === coordinate) {
          pendingWorldLookAt.entityId = lookAtEntity?.networkId ?? null;
          resolvePendingEntityTooltip();
        }
        if (worldPointer !== source) {
          return;
        }
        const item = reversedEntities.find((entity) => entity.tags.includes('illarion:item') && entity.visual);
        if (!item?.visual) {
          return;
        }
        preview.visual = item.visual;
        preview.seed = String(item.networkId);
        preview.left = clientX;
        preview.top = clientY;
        void nextTick(() => updatePreviewPosition(clientX, clientY));
      })
      .catch(() => undefined);
  }
};

const resetPointers = () => {
  inventoryPointer = undefined;
  worldPointer = undefined;
  preview.visual = undefined;
  preview.seed = undefined;
};

const releaseOn = (target: InventoryDropTarget) => {
  if (inventoryPointer) {
    const { slot: source, item, dragged } = inventoryPointer;
    if (dragged) {
      suppressedClick = { x: target.clientX, y: target.clientY, button: 0 };
      target.acceptSlot(source, item, inventory.counter.value);
    }
  } else if (worldPointer?.dragged && target.acceptCoordinate) {
    target.acceptCoordinate(worldPointer.coordinate, inventory.counter.value);
  }
  resetPointers();
};

provide(inventoryDragKey, { start: startInventoryDrag, releaseOn });

const onPointerUp = ({ button, clientX, clientY, coordinate }: SelenePointerEvent) => {
  if (inventoryPointer) {
    const { slot: source, dragged } = inventoryPointer;
    if (dragged) {
      suppressedClick = { x: clientX, y: clientY, button };
      if (isInWorldViewport(clientX, clientY)) {
        inventory.moveSlotToCoordinate(source.viewId, source.slotId, coordinate, inventory.counter.value);
      }
    }
  } else if (worldPointer?.dragged) {
    suppressedClick = { x: clientX, y: clientY, button };
    if (isInWorldViewport(clientX, clientY)) {
      inventory.moveCoordinateToCoordinate(worldPointer.coordinate, coordinate, inventory.counter.value);
    }
  }
  resetPointers();
};

onMounted(() => {
  window.addEventListener('mousemove', onMouseMove, true);
  window.addEventListener('click', onClick, true);
  window.addEventListener('keyup', finishUse, true);
  inputUnsubscribers.push(selene.input.onPointerDown(onPointerDown));
  inputUnsubscribers.push(selene.input.onPointerUp(onPointerUp));
  networkUnsubscribers.push(
    selene.network.onPayload('illarion:look_at', (payload) => {
      const pending = pendingWorldLookAt;
      if (
        !pending ||
        payload.x !== pending.coordinate.x ||
        payload.y !== pending.coordinate.y ||
        payload.z !== pending.coordinate.z
      ) {
        return;
      }
      showWorldTooltip(payload.tooltip);
    }),
  );
  networkUnsubscribers.push(
    selene.network.onPayload('illarion:look_at_entity', (payload) => {
      if (!pendingWorldLookAt || typeof payload.networkId !== 'number') {
        return;
      }
      pendingEntityTooltip = { networkId: payload.networkId, tooltip: payload.tooltip };
      resolvePendingEntityTooltip();
    }),
  );
});
onUnmounted(() => {
  window.removeEventListener('mousemove', onMouseMove, true);
  window.removeEventListener('click', onClick, true);
  window.removeEventListener('keyup', finishUse, true);
  inputUnsubscribers.splice(0).forEach((unsubscribe) => unsubscribe());
  networkUnsubscribers.splice(0).forEach((unsubscribe) => unsubscribe());
});
</script>

<template>
  <slot />
  <span
    ref="worldTooltipAnchor"
    class="world-tooltip-anchor"
    :style="{ left: `${worldTooltipPosition.left}px`, top: `${worldTooltipPosition.top}px` }"
  />
  <span
    v-if="preview.visual && preview.seed"
    ref="previewElement"
    class="drag-preview-overlay"
    :style="{ left: `${preview.left}px`, top: `${preview.top}px` }"
  >
    <SeleneVisual :identifier="preview.visual" :seed="preview.seed" without-offset />
  </span>
</template>

<style scoped>
.world-tooltip-anchor {
  position: absolute;
  width: 1px;
  height: 1px;
  pointer-events: none;
}
.drag-preview-overlay {
  position: absolute;
  z-index: 10;
  display: block;
  width: 0;
  height: 0;
  opacity: 0.85;
  user-select: none;
  pointer-events: none;
}
</style>

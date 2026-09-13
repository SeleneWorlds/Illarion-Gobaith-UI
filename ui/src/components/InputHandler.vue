<script setup lang="ts">
import { nextTick, onMounted, onUnmounted, provide, reactive, useTemplateRef } from 'vue';
import {
  sameInventorySlot,
  type InventoryDragStartDetail,
  type InventoryItem,
  type InventorySlotDefinition,
} from '../inventory';
import type { Coordinate, SelenePointerEvent } from '../selene';
import { useSelene } from '../selene';
import { inventoryDragKey } from '../inventoryDrag';
import { useInventoryStore } from '../stores/inventory';
import SeleneVisual from './SeleneVisual.vue';

const isInWorldViewport = (x: number, y: number) => x >= 0 && x < 839 && y >= 0 && y < 419;

const inventorySlotFromEvent = (event: MouseEvent): InventorySlotDefinition | undefined => {
  const candidate = event
    .composedPath()
    .find((node): node is HTMLElement => node instanceof HTMLElement && node.matches('[data-inventory-slot-button]'));
  if (!(candidate instanceof HTMLElement)) {
    return undefined;
  }

  const viewId = candidate.dataset.viewId;
  const slotId = Number(candidate.dataset.slotId);
  return (viewId === 'equipment' || viewId === 'belt') && Number.isInteger(slotId) ? { viewId, slotId } : undefined;
};

interface InventoryPointer {
  slot: InventorySlotDefinition;
  item: InventoryItem;
  downX: number;
  downY: number;
  dragged: boolean;
}

const selene = useSelene();
const inventory = useInventoryStore();
const previewElement = useTemplateRef<HTMLElement>('previewElement');
const preview = reactive({
  item: undefined as InventoryItem | undefined,
  slot: undefined as InventorySlotDefinition | undefined,
  left: 0,
  top: 0,
});
let inventoryPointer: InventoryPointer | undefined;
let worldPointer: Coordinate | undefined;
let suppressedClick: { x: number; y: number; button: number } | undefined;

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

const startInventoryDrag = ({ viewId, slotId, clientX, clientY }: InventoryDragStartDetail) => {
  suppressedClick = undefined;
  const slot = { viewId, slotId };
  const item = inventory.getItem(slot.viewId, slot.slotId);
  if (!item) {
    return;
  }
  inventoryPointer = { slot, item, downX: clientX, downY: clientY, dragged: false };
  preview.item = item;
  preview.slot = slot;
  preview.left = clientX;
  preview.top = clientY;
  void nextTick(() => updatePreviewPosition(clientX, clientY));
};

provide(inventoryDragKey, { start: startInventoryDrag });

const finishUse = (event: KeyboardEvent) => {
  if (event.key === 'Shift') {
    inventory.finishUse();
  }
};

const onMouseMove = (event: MouseEvent) => {
  if (!inventoryPointer) {
    return;
  }
  inventoryPointer.dragged ||=
    Math.abs(event.clientX - inventoryPointer.downX) + Math.abs(event.clientY - inventoryPointer.downY) > 3;
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
    worldPointer = coordinate;
  }
};

const resetPointers = () => {
  inventoryPointer = undefined;
  worldPointer = undefined;
  preview.item = undefined;
  preview.slot = undefined;
};

const onMouseUp = (event: MouseEvent) => {
  if (event.button !== 0) {
    return;
  }
  const target = inventorySlotFromEvent(event);
  if (!target) {
    return;
  }
  if (inventoryPointer) {
    const { slot: source, dragged } = inventoryPointer;
    if (dragged) {
      suppressedClick = { x: event.clientX, y: event.clientY, button: event.button };
    }
    if (dragged && !sameInventorySlot(target, source)) {
      inventory.moveSlotToSlot(source.viewId, source.slotId, target.viewId, target.slotId, inventory.counter.value);
    }
  } else if (worldPointer) {
    inventory.moveCoordinateToSlot(worldPointer, target.viewId, target.slotId, inventory.counter.value);
  }
  resetPointers();
};

const onPointerUp = ({ button, clientX, clientY, coordinate }: SelenePointerEvent) => {
  if (inventoryPointer) {
    const { slot: source, dragged } = inventoryPointer;
    if (dragged) {
      suppressedClick = { x: clientX, y: clientY, button };
      inventory.moveSlotToCoordinate(source.viewId, source.slotId, coordinate, inventory.counter.value);
    }
  }
  resetPointers();
};

onMounted(() => {
  window.addEventListener('mousemove', onMouseMove, true);
  window.addEventListener('mouseup', onMouseUp, true);
  window.addEventListener('click', onClick, true);
  window.addEventListener('keyup', finishUse, true);
  selene.input.onPointerDown(onPointerDown);
  selene.input.onPointerUp(onPointerUp);
});
onUnmounted(() => {
  window.removeEventListener('mousemove', onMouseMove, true);
  window.removeEventListener('mouseup', onMouseUp, true);
  window.removeEventListener('click', onClick, true);
  window.removeEventListener('keyup', finishUse, true);
});
</script>

<template>
  <slot />
  <span
    v-if="preview.item && preview.slot"
    ref="previewElement"
    class="drag-preview-overlay"
    :style="{ left: `${preview.left}px`, top: `${preview.top}px` }"
  >
    <SeleneVisual
      :identifier="preview.item.visual"
      :seed="`${preview.slot.viewId}:${preview.slot.slotId}`"
      without-offset
    />
  </span>
</template>

<style scoped>
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

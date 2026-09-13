<script setup lang="ts">
import { nextTick, onMounted, onUnmounted, reactive, useTemplateRef } from 'vue';
import type { InventoryItem, InventorySlotDefinition } from '../inventory';
import { inventorySlotAt, isInWorldViewport, sameInventorySlot } from '../inventoryInteractions';
import type { Coordinate, SelenePointerEvent } from '../selene';
import { useSelene } from '../selene';
import { useInventoryStore } from '../stores/inventory';
import SeleneVisual from './SeleneVisual.vue';

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
const inputUnsubscribers: Array<() => void> = [];

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

const onMouseDown = (event: MouseEvent) => {
  suppressedClick = undefined;
  if (event.button !== 0) {
    return;
  }
  const slot = inventorySlotAt(event.clientX, event.clientY);
  if (!slot) {
    return;
  }
  const item = inventory.getItem(slot.viewId, slot.slotId);
  if (!item) {
    return;
  }
  if (event.shiftKey) {
    inventory.selectUseSlot(slot.viewId, slot.slotId);
  }
  inventoryPointer = { slot, item, downX: event.clientX, downY: event.clientY, dragged: false };
  preview.item = item;
  preview.slot = slot;
  preview.left = event.clientX;
  preview.top = event.clientY;
  void nextTick(() => updatePreviewPosition(event.clientX, event.clientY));
};

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

const onPointerUp = ({ button, clientX, clientY, coordinate }: SelenePointerEvent) => {
  const target = inventorySlotAt(clientX, clientY);
  if (inventoryPointer) {
    const { slot: source, dragged } = inventoryPointer;
    if (dragged) {
      suppressedClick = { x: clientX, y: clientY, button };
    }
    if (dragged && target && !sameInventorySlot(target, source)) {
      inventory.moveSlotToSlot(source.viewId, source.slotId, target.viewId, target.slotId, inventory.counter.value);
    } else if (dragged && !target && isInWorldViewport(clientX, clientY)) {
      inventory.moveSlotToCoordinate(source.viewId, source.slotId, coordinate, inventory.counter.value);
    }
  } else if (worldPointer && target) {
    inventory.moveCoordinateToSlot(worldPointer, target.viewId, target.slotId, inventory.counter.value);
  }
  inventoryPointer = undefined;
  worldPointer = undefined;
  preview.item = undefined;
  preview.slot = undefined;
};

onMounted(() => {
  window.addEventListener('mousedown', onMouseDown, true);
  window.addEventListener('mousemove', onMouseMove, true);
  window.addEventListener('click', onClick, true);
  window.addEventListener('keyup', finishUse, true);
  inputUnsubscribers.push(selene.input.onPointerDown(onPointerDown), selene.input.onPointerUp(onPointerUp));
});
onUnmounted(() => {
  window.removeEventListener('mousedown', onMouseDown, true);
  window.removeEventListener('mousemove', onMouseMove, true);
  window.removeEventListener('click', onClick, true);
  window.removeEventListener('keyup', finishUse, true);
  inputUnsubscribers.splice(0).forEach((release) => release());
});
</script>

<template>
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

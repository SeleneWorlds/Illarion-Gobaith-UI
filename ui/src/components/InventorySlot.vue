<script setup lang="ts">
import { computed, inject } from 'vue';
import { useClientAssetSrc, useClientAssetStyle } from '../composables/useClientAsset';
import { sameInventorySlot, type InventoryViewId } from '../inventory';
import { inventoryDragKey } from '../inventoryDrag';
import { useMenu } from '../overlays';
import { useInventoryStore } from '../stores/inventory';
import InventoryItemMenu from './InventoryItemMenu.vue';
import SeleneVisual from './SeleneVisual.vue';

const props = defineProps<{ viewId: InventoryViewId; slotId: number }>();

const slotBackground = useClientAssetStyle('client/textures/illarion/ui/inv_slot-0.png');
const hoverBackground = useClientAssetStyle('client/textures/illarion/ui/inv_slot-7.png');
const markUseSrc = useClientAssetSrc('client/textures/illarion/ui/mark_use.png');

const inventory = useInventoryStore();
const inventoryDrag = inject(inventoryDragKey);
if (!inventoryDrag) {
  throw new Error('Inventory drag API was not provided.');
}
const menu = useMenu();

const item = computed(() => inventory.getItem(props.viewId, props.slotId));
const isUsing = computed(() =>
  inventory.selectedUseSlots.value.some((slot) => slot.viewId === props.viewId && slot.slotId === props.slotId),
);

const hitBands = Array.from({ length: 20 }, (_, index) => {
  const top = index * 2;
  const height = Math.min(2, 39 - top);
  const distanceFromCenter = Math.abs(19.5 - (top + height / 2));
  const left = Math.floor(distanceFromCenter * 2);
  return { top, left, width: 78 - left * 2, height };
});

const lookAt = () => {
  if (item.value) {
    inventory.lookAt(props.viewId, props.slotId);
  }
};
const onMouseDown = (event: MouseEvent) => {
  if (!item.value) {
    return;
  }
  if (event.shiftKey) {
    inventory.selectUseSlot(props.viewId, props.slotId);
    return;
  }
  inventoryDrag.start({
    viewId: props.viewId,
    slotId: props.slotId,
    clientX: event.clientX,
    clientY: event.clientY,
  });
};
const onClick = (event: MouseEvent) => {
  if (!event.shiftKey) {
    lookAt();
  }
};
const onMouseUp = (event: MouseEvent) => {
  const target = { viewId: props.viewId, slotId: props.slotId };
  inventoryDrag.releaseOn({
    clientX: event.clientX,
    clientY: event.clientY,
    acceptSlot(source, _item, count) {
      if (!sameInventorySlot(source, target)) {
        inventory.moveSlotToSlot(source.viewId, source.slotId, target.viewId, target.slotId, count);
      }
    },
    acceptCoordinate(source, count) {
      inventory.moveCoordinateToSlot(source, target.viewId, target.slotId, count);
    },
  });
};
type ItemMenuAction = 'open' | 'lookAt' | 'use' | 'useWith' | 'drop';
const onContextMenu = async (event: MouseEvent) => {
  if (!item.value) {
    return;
  }
  const action = await menu.open<ItemMenuAction>(
    InventoryItemMenu,
    {
      canOpen: item.value.container,
    },
    { label: 'Item actions', position: { x: event.clientX, y: event.clientY } },
  );
  if (action === 'open') {
    inventory.openContainer(props.viewId, props.slotId, inventory.counter.value);
  } else if (action === 'lookAt') {
    inventory.lookAt(props.viewId, props.slotId);
  } else if (action === 'use') {
    inventory.use(props.viewId, props.slotId, inventory.counter.value);
  } else if (action === 'useWith') {
    inventory.selectUseSlot(props.viewId, props.slotId);
  } else if (action === 'drop') {
    inventory.dropInFront(props.viewId, props.slotId, inventory.counter.value);
  }
};

const onScrollSlot = (event: WheelEvent) => {
  inventory.setCounter(inventory.counter.value + (event.deltaY < 0 ? 1 : -1));
};
</script>

<template>
  <div class="inventory-slot" data-inventory-slot>
    <button
      type="button"
      class="button"
      data-inventory-slot-button
      :data-view-id="viewId"
      :data-slot-id="slotId"
      :aria-label="`${viewId} slot ${slotId}`"
      @mousedown.left.prevent="onMouseDown"
      @mouseup.left.prevent.stop="onMouseUp"
      @click="onClick"
      @contextmenu.prevent.stop="onContextMenu"
      @wheel.prevent="onScrollSlot"
    >
      <span
        v-for="band in hitBands"
        :key="band.top"
        class="hit"
        data-selene-interactive
        :style="{ top: `${band.top}px`, left: `${band.left}px`, width: `${band.width}px`, height: `${band.height}px` }"
      />
      <SeleneVisual v-if="item" class="item" :identifier="item.visual" :seed="`${viewId}:${slotId}`" without-offset />
      <span v-if="item && item.count > 1" class="count">{{ item.count }}</span>
    </button>
    <img v-if="isUsing" class="using" :src="markUseSrc" alt="Item currently being used" />
  </div>
</template>

<style scoped>
.inventory-slot {
  position: absolute;
  width: 78px;
  height: 39px;
  pointer-events: none;
}
.button {
  position: absolute;
  inset: 0;
  width: 78px;
  height: 39px;
  margin: 0;
  padding: 0;
  overflow: hidden;
  border: 0;
  clip-path: polygon(50% 0, 100% 50%, 50% 100%, 0 50%);
  background: v-bind(slotBackground) no-repeat;
  cursor: grab;
  pointer-events: none;
}
.button:has(.hit:hover) {
  background-image: v-bind(hoverBackground);
}
.button:active {
  cursor: grabbing;
}
.button:focus-visible {
  outline: 1px solid #b7d9ba;
  outline-offset: -2px;
}
.hit {
  position: absolute;
  z-index: 2;
  display: block;
  pointer-events: auto;
}
.item {
  position: absolute;
  inset: 0;
  display: block;
  user-select: none;
  pointer-events: none;
}
.count {
  position: absolute;
  z-index: 3;
  right: 17px;
  bottom: 7px;
  color: white;
  font:
    bold 12px Arial,
    sans-serif;
  line-height: 1;
  text-shadow:
    -1px -1px #000,
    1px -1px #000,
    -1px 1px #000,
    1px 1px #000;
  pointer-events: none;
}
.using {
  position: absolute;
  z-index: 4;
  top: 19.5px;
  left: 39px;
  width: 139px;
  height: 71px;
  transform: translate(-50%, -50%);
  pointer-events: none;
}
</style>

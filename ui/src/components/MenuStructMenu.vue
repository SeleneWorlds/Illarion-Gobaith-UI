<script setup lang="ts">
import { onBeforeUnmount, ref } from 'vue';
import { useClientAssetSrc, useClientAssetStyle } from '../composables/useClientAsset';
import { useTooltip } from '../overlays';
import { useSelene, type ClientNetworkPayload } from '../selene';
import SeleneVisual from './SeleneVisual.vue';

interface MenuStructItem {
  id: number;
  visual: string;
}

const SLOT_COUNT = 20;
const selene = useSelene();
const tooltip = useTooltip();
const selectionBackground = useClientAssetStyle('client/textures/illarion/ui/menu_select.png');
const frameSrc = useClientAssetSrc('client/textures/illarion/ui/menu_short.png');
const menuId = ref<number>();
const items = ref<Array<MenuStructItem | undefined>>([]);
const hoveredSlot = ref<number>();
let tooltipAnchor: HTMLElement | undefined;

const parseItem = (value: unknown): MenuStructItem | undefined => {
  if (!value || typeof value !== 'object') {
    return undefined;
  }
  const item = value as ClientNetworkPayload;
  return typeof item.id === 'number' && typeof item.visual === 'string'
    ? { id: item.id, visual: item.visual }
    : undefined;
};

const hide = () => {
  menuId.value = undefined;
  items.value = [];
  hoveredSlot.value = undefined;
  tooltipAnchor = undefined;
  tooltip.hide();
};

const lookAt = (item: MenuStructItem, slotIndex: number, event: Event) => {
  if (menuId.value === undefined || !(event.currentTarget instanceof HTMLElement)) {
    return;
  }
  if (hoveredSlot.value === slotIndex && tooltipAnchor === event.currentTarget) {
    return;
  }
  hoveredSlot.value = slotIndex;
  tooltipAnchor = event.currentTarget;
  tooltip.hide();
  selene.network.sendToServer('illarion:look_at_menu_item', {
    id: menuId.value,
    slotIndex,
    itemId: item.id,
  });
};

const leaveItem = (slotIndex: number) => {
  if (hoveredSlot.value !== slotIndex) {
    return;
  }
  hoveredSlot.value = undefined;
  tooltipAnchor = undefined;
  tooltip.hide();
};

const select = (item: MenuStructItem) => {
  if (menuId.value === undefined) {
    return;
  }
  selene.network.sendToServer('illarion:menu_struct', { id: menuId.value, itemId: item.id });
  hide();
};

const unsubscribe = selene.network.onPayload('illarion:menu_struct', (payload) => {
  if (typeof payload.id !== 'number') {
    hide();
    return;
  }
  hoveredSlot.value = undefined;
  tooltipAnchor = undefined;
  tooltip.hide();
  menuId.value = payload.id;
  items.value = Array.from({ length: SLOT_COUNT }, (_, index) =>
    Array.isArray(payload.items) ? parseItem(payload.items[index]) : undefined,
  );
});

const unsubscribeLookAt = selene.network.onPayload('illarion:look_at_menu_item', (payload) => {
  if (payload.id !== menuId.value || payload.slotIndex !== hoveredSlot.value || typeof payload.slotIndex !== 'number') {
    return;
  }
  const item = items.value[payload.slotIndex - 1];
  if (!item || payload.itemId !== item.id || !payload.tooltip || typeof payload.tooltip !== 'object') {
    return;
  }
  const value = payload.tooltip as ClientNetworkPayload;
  if (!tooltipAnchor) {
    return;
  }
  tooltip.show({
    anchor: tooltipAnchor,
    title: typeof value.name === 'string' ? value.name : '',
    description: typeof value.description === 'string' ? value.description : undefined,
    immediate: true,
  });
});

onBeforeUnmount(() => {
  tooltip.hide();
  unsubscribe();
  unsubscribeLookAt();
});
</script>

<template>
  <section v-if="menuId !== undefined" class="menu-struct" aria-label="Selection menu" data-selene-interactive>
    <img class="frame" :src="frameSrc" alt="" />
    <div class="slots">
      <button
        v-for="(item, index) in items"
        :key="index"
        class="slot"
        :class="{ empty: !item }"
        type="button"
        :aria-label="item ? `Select item ${item.id}` : undefined"
        :disabled="!item"
        @mouseenter="item && lookAt(item, index + 1, $event)"
        @mouseleave="leaveItem(index + 1)"
        @focus="item && lookAt(item, index + 1, $event)"
        @blur="leaveItem(index + 1)"
        @click="item && select(item)"
      >
        <SeleneVisual v-if="item" :identifier="item.visual" :seed="String(item.id)" without-offset />
      </button>
    </div>
  </section>
</template>

<style scoped>
.menu-struct {
  position: absolute;
  z-index: 20;
  top: 239px;
  left: 315px;
  width: 395px;
  height: 290px;
  pointer-events: auto;
}
.frame {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
}
.slots {
  position: absolute;
  top: 52px;
  left: 38px;
  display: grid;
  grid-template-columns: repeat(5, 64px);
  grid-auto-rows: 48px;
}
.slot {
  position: relative;
  width: 64px;
  height: 48px;
  margin: 0;
  padding: 0;
  border: 0;
  outline: 0;
  background: transparent;
  cursor: pointer;
}
.slot:hover,
.slot:focus-visible {
  background: v-bind(selectionBackground) center / 64px 48px no-repeat;
}
.slot.empty {
  visibility: hidden;
}
</style>

<script setup lang="ts">
import { computed, onBeforeUnmount, useTemplateRef } from 'vue';
import { useUiAssetSrc } from '../composables/useClientAsset';
import { useInventoryStore, type ShowcaseDefinition } from '../stores/inventory';
import InventorySlot from './InventorySlot.vue';

const props = defineProps<{ showcase: ShowcaseDefinition }>();
const inventory = useInventoryStore();
const background = useUiAssetSrc('showcase_back.png');
const viewId = computed(() => `showcase:${props.showcase.id}` as const);
const slots = computed(() => Array.from({ length: props.showcase.slotCount }, (_, index) => index + 1));
const slotsElement = useTemplateRef<HTMLElement>('slotsElement');
const SCROLL_DECAY_MS = 180;
const MIN_SCROLL_VELOCITY = 0.01;
let scrollVelocity = 0;
let scrollAnimationFrame: number | undefined;
let previousFrameTime: number | undefined;
const slotColumns = computed(() => {
  const columns: number[][] = [];

  for (let slotIndex = 0; slotIndex < slots.value.length;) {
    const columnSize = columns.length % 2 === 0 ? 3 : 2;
    columns.push(slots.value.slice(slotIndex, slotIndex + columnSize));
    slotIndex += columnSize;
  }

  return columns;
});

const animateScroll = (time: number) => {
  const element = slotsElement.value;
  if (!element) {
    scrollAnimationFrame = undefined;
    previousFrameTime = undefined;
    return;
  }

  const elapsed = Math.min(time - (previousFrameTime ?? time), 50);
  const decay = Math.exp(-elapsed / SCROLL_DECAY_MS);
  const distance = scrollVelocity * SCROLL_DECAY_MS * (1 - decay);
  const previousScrollLeft = element.scrollLeft;

  element.scrollLeft += distance;
  scrollVelocity *= decay;
  previousFrameTime = time;

  const reachedEdge = element.scrollLeft === previousScrollLeft && Math.abs(distance) > 0;
  if (reachedEdge || Math.abs(scrollVelocity) < MIN_SCROLL_VELOCITY) {
    scrollVelocity = 0;
    scrollAnimationFrame = undefined;
    previousFrameTime = undefined;
    return;
  }

  scrollAnimationFrame = requestAnimationFrame(animateScroll);
};

const onWheel = (event: WheelEvent) => {
  const element = slotsElement.value;
  if (!element) {
    return;
  }

  const delta = event.deltaX !== 0 ? event.deltaX : event.deltaY;
  const unit =
    event.deltaMode === WheelEvent.DOM_DELTA_LINE
      ? 16
      : event.deltaMode === WheelEvent.DOM_DELTA_PAGE
        ? element.clientWidth
        : 1;
  scrollVelocity += (delta * unit) / SCROLL_DECAY_MS;

  if (scrollAnimationFrame === undefined) {
    previousFrameTime = undefined;
    scrollAnimationFrame = requestAnimationFrame(animateScroll);
  }
};

onBeforeUnmount(() => {
  if (scrollAnimationFrame !== undefined) {
    cancelAnimationFrame(scrollAnimationFrame);
  }
});
</script>

<template>
  <section
    class="showcase"
    :class="showcase.id === 0 ? 'showcase-right' : 'showcase-left'"
    :aria-label="`Container ${showcase.id + 1}`"
    data-selene-interactive
    @wheel.prevent.stop="onWheel"
  >
    <img class="background" :src="background" alt="" />
    <div ref="slotsElement" class="slots">
      <div
        v-for="(slotColumn, columnIndex) in slotColumns"
        :key="columnIndex"
        class="slot-column"
        :class="{ 'slot-column-staggered': columnIndex % 2 === 1 }"
      >
        <InventorySlot
          v-for="slotId in slotColumn"
          :key="slotId"
          class="slot"
          :view-id="viewId"
          :slot-id="slotId"
          :can-scroll-counter="false"
        />
      </div>
    </div>
    <button class="close" type="button" aria-label="Close container" @click="inventory.closeShowcase(showcase.id)" />
  </section>
</template>

<style scoped>
.showcase {
  position: absolute;
  z-index: 8;
  bottom: 0;
  width: 383px;
  height: 143px;
  pointer-events: auto;
}
.showcase-left {
  left: 0;
}
.showcase-right {
  left: 460px;
}
.background {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  user-select: none;
  pointer-events: none;
}
.slots {
  position: absolute;
  top: 13px;
  left: 8px;
  display: flex;
  gap: 2px;
  max-width: 320px;
  max-height: 121px;
  overflow-x: auto;
  overflow-y: hidden;
  scrollbar-width: none;
}
.slots::-webkit-scrollbar {
  display: none;
}
.slot-column {
  display: flex;
  flex: 0 0 39px;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.slot-column-staggered {
  padding-top: 20.5px;
}
.slot {
  position: relative;
  flex: 0 0 39px;
  width: 78px;
}
.close {
  position: absolute;
  right: 8px;
  bottom: 6px;
  z-index: 3;
  width: 27px;
  height: 39px;
  padding: 0;
  border: 0;
  background: transparent;
  cursor: pointer;
}
</style>

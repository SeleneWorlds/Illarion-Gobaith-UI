<script setup lang="ts">
import { onBeforeUnmount, ref } from 'vue';
import { useSelene } from '../selene';
import { useInventoryStore } from '../stores/inventory';
import ClockDisplay from './ClockDisplay.vue';
import CounterModal from './CounterModal.vue';
import ContextMenu from './ContextMenu.vue';

const selene = useSelene();
const inventory = useInventoryStore();
const DRAG_STEP = 5;
const presets = [1, 5, 10, 100, 250];
const counter = inventory.counter;
const menuOpen = ref(false);
const modalOpen = ref(false);
let dragOrigin: { x: number; y: number; value: number } | undefined;
let dragged = false;

const setCounter = (value: number) => {
  inventory.setCounter(value);
};
const openModal = () => {
  if (dragged) return;
  menuOpen.value = false;
  modalOpen.value = true;
};
const confirmModal = (value: number) => {
  setCounter(value);
  modalOpen.value = false;
};
const cancelModal = () => {
  modalOpen.value = false;
};
const onKeydown = (event: KeyboardEvent) => {
  if (event.key !== 'ArrowUp' && event.key !== 'ArrowDown') return;
  event.preventDefault();
  setCounter(counter.value + (event.key === 'ArrowUp' ? 1 : -1));
};
const onWheel = (event: WheelEvent) => {
  event.preventDefault();
  setCounter(counter.value + (event.deltaY < 0 ? 1 : -1));
};
const onDragMove = (event: MouseEvent) => {
  if (!dragOrigin) return;
  const horizontal = Math.trunc((dragOrigin.x - event.clientX) / DRAG_STEP) * 10;
  const vertical = Math.trunc((dragOrigin.y - event.clientY) / DRAG_STEP);
  dragged ||= horizontal !== 0 || vertical !== 0;
  setCounter(dragOrigin.value + horizontal + vertical);
};
const endDrag = () => {
  dragOrigin = undefined;
  window.removeEventListener('mousemove', onDragMove, true);
  window.removeEventListener('mouseup', endDrag, true);
};
const startDrag = (event: MouseEvent) => {
  if (event.button !== 0) return;
  dragged = false;
  dragOrigin = { x: event.clientX, y: event.clientY, value: counter.value };
  window.addEventListener('mousemove', onDragMove, true);
  window.addEventListener('mouseup', endDrag, true);
  event.preventDefault();
};
const selectPreset = (value: number) => {
  setCounter(value);
  menuOpen.value = false;
};

onBeforeUnmount(endDrag);
</script>

<template>
  <section class="counter" aria-label="Counter and clock">
    <img :src="selene.resolveAsset('./assets/gui_counter.png')" alt="">
    <button class="value" type="button" aria-label="Item counter"
            title="Number of items to move (1–250); drag to adjust; click to edit"
            data-selene-interactive @mousedown="startDrag" @click="openModal"
            @contextmenu.prevent.stop="menuOpen = true" @keydown="onKeydown" @wheel="onWheel">
      {{ counter }}
    </button>
    <ContextMenu v-model:open="menuOpen" class="menu" label="Counter presets">
      <li v-for="preset in presets" :key="preset">
        <button type="button" @click="selectPreset(preset)">{{ preset }}</button>
      </li>
    </ContextMenu>
    <CounterModal v-if="modalOpen" :value="counter"
                  @confirm="confirmModal" @cancel="cancelModal" />
    <ClockDisplay />
  </section>
</template>

<style scoped>
.counter {
  position: absolute;
  bottom: 0;
  left: 385px;
  width: 71px;
  height: 120px;
  color: #d8e4ff;
  text-align: center;
  text-shadow: 1px 1px 2px #000;
}

.counter > img {
  position: absolute;
  inset: 0;
  display: block;
  width: 71px;
  height: 120px;
  user-select: none;
}

.value {
  position: absolute;
  right: 8px;
  bottom: 60px;
  left: 8px;
  width: 55px;
  height: 24px;
  padding: 0; border: 0; outline: 0; background: transparent; color: #B2CCFF;
  font: inherit; font-size: 17px; text-align: center; text-shadow: inherit;
  cursor: ns-resize; pointer-events: auto; user-select: none;
}
.value:focus-visible { outline: 1px solid #b7d9ba; }
.menu { right: 4px; bottom: 82px; }
</style>

<script setup lang="ts">
import { nextTick, onBeforeUnmount, ref } from 'vue';
import ContextMenu from './ContextMenu.vue';

defineProps<{ menuFrameSrc: string }>();

const MIN_COUNTER = 1;
const MAX_COUNTER = 250;
const DRAG_STEP = 5;
const presets = [1, 5, 10, 100, 250];
const counter = defineModel<number>({ required: true });
const editor = ref<HTMLDialogElement>();
const editorInput = ref<HTMLInputElement>();
const counterText = ref(String(counter.value));
const menuOpen = ref(false);
let dragOrigin: { x: number; y: number; value: number } | undefined;
let dragged = false;

const setCounter = (value: number) => {
  counter.value = Math.min(MAX_COUNTER, Math.max(MIN_COUNTER, Math.round(value)));
  counterText.value = String(counter.value);
};
const onInput = (event: Event) => {
  const target = event.target as HTMLInputElement;
  counterText.value = target.value.replace(/\D/g, '').slice(0, 3);
};
const commit = () => {
  const value = Number(counterText.value);
  setCounter(Number.isFinite(value) ? value : counter.value);
};
const openEditor = async () => {
  if (dragged) return;
  menuOpen.value = false;
  counterText.value = String(counter.value);
  editor.value?.showModal();
  await nextTick();
  editorInput.value?.select();
};
const confirmEditor = () => {
  commit();
  editor.value?.close();
};
const cancelEditor = () => {
  counterText.value = String(counter.value);
  editor.value?.close();
};
const onKeydown = (event: KeyboardEvent) => {
  if (event.key !== 'ArrowUp' && event.key !== 'ArrowDown') return;
  event.preventDefault();
  setCounter(counter.value + (event.key === 'ArrowUp' ? 1 : -1));
};
const onEditorKeydown = (event: KeyboardEvent) => {
  event.stopPropagation();
  if (event.key === 'Enter') {
    event.preventDefault();
    confirmEditor();
  } else if (event.key === 'Escape') {
    event.preventDefault();
    cancelEditor();
  } else if (event.key === 'ArrowUp' || event.key === 'ArrowDown') {
    event.preventDefault();
    setCounter(counter.value + (event.key === 'ArrowUp' ? 1 : -1));
  }
};
const onWheel = (event: WheelEvent) => {
  event.preventDefault();
  setCounter(counter.value + (event.deltaY < 0 ? 1 : -1));
};
const onDragMove = (event: MouseEvent) => {
  if (!dragOrigin) return;
  const horizontal = Math.trunc((dragOrigin.x - event.clientX) / DRAG_STEP) * 10;
  // LWJGL's legacy mouse Y axis grows upward; DOM clientY grows downward.
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
  <button class="counter__value" type="button" aria-label="Item counter"
          title="Number of items to move (1–250); drag to adjust; click to edit"
          data-selene-interactive @mousedown="startDrag" @click="openEditor"
          @contextmenu.prevent.stop="menuOpen = true" @keydown="onKeydown" @wheel="onWheel">
    {{ counter }}
  </button>
  <ContextMenu class="counter-menu" :open="menuOpen" variant="long" :frame-src="menuFrameSrc"
               label="Counter presets" @close="menuOpen = false">
    <li v-for="preset in presets" :key="preset">
      <button type="button" @click="selectPreset(preset)">{{ preset }}</button>
    </li>
  </ContextMenu>
  <dialog ref="editor" class="counter-editor" data-selene-interactive @cancel.prevent="cancelEditor">
    <form method="dialog" @submit.prevent="confirmEditor">
      <label for="counter-input">Number of items to move (1–250)</label>
      <input id="counter-input" ref="editorInput" v-model="counterText" type="text"
             inputmode="numeric" maxlength="3" @input="onInput" @keydown="onEditorKeydown" @keyup.stop>
      <div class="counter-editor__actions">
        <button type="submit">Set</button>
        <button type="button" @click="cancelEditor">Cancel</button>
      </div>
    </form>
  </dialog>
</template>

<style scoped>
.counter__value {
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
.counter__value:focus-visible { outline: 1px solid #b7d9ba; }
.counter-menu { right: 4px; bottom: 82px; }
.counter-editor { width: 250px; padding: 18px; border: 1px solid #806744; background: #e6d1a7; color: #342515; }
.counter-editor::backdrop { background: rgb(0 0 0 / 45%); }
.counter-editor form { display: grid; gap: 12px; }
.counter-editor input { width: 100%; box-sizing: border-box; font: inherit; }
.counter-editor__actions { display: flex; justify-content: flex-end; gap: 8px; }
</style>

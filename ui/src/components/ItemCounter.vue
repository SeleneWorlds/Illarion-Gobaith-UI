<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, ref } from 'vue';
import ContextMenu from './ContextMenu.vue';

defineProps<{
  menuFrameSrc: string;
  editorFrameSrc: string;
  confirmSrc: string;
  cancelSrc: string;
}>();

const MIN_COUNTER = 1;
const MAX_COUNTER = 250;
const DRAG_STEP = 5;
const presets = [1, 5, 10, 100, 250];
const counter = defineModel<number>({ required: true });
const editorInput = ref<HTMLInputElement>();
const counterText = ref(String(counter.value));
const menuOpen = ref(false);
const editorOpen = ref(false);
const editorValue = computed(() => Number(counterText.value));
const editorValid = computed(() => /^\d{1,3}$/.test(counterText.value)
  && editorValue.value >= MIN_COUNTER && editorValue.value <= MAX_COUNTER);
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
  if (editorValid.value) setCounter(editorValue.value);
};
const openEditor = async () => {
  if (dragged) return;
  menuOpen.value = false;
  counterText.value = String(counter.value);
  editorOpen.value = true;
  await nextTick();
  editorInput.value?.select();
};
const confirmEditor = () => {
  if (!editorValid.value) return;
  commit();
  editorOpen.value = false;
};
const cancelEditor = () => {
  counterText.value = String(counter.value);
  editorOpen.value = false;
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
  <template v-if="editorOpen">
    <span class="counter-editor__scrim" data-selene-interactive aria-hidden="true" @click="cancelEditor" />
    <section class="counter-editor" data-selene-interactive role="dialog" aria-modal="true"
             aria-labelledby="counter-editor-title" @click.stop @keydown.stop>
      <img class="counter-editor__frame" :src="editorFrameSrc" alt="">
      <form @submit.prevent="confirmEditor">
        <label id="counter-editor-title" for="counter-input">Enter new number</label>
        <input id="counter-input" ref="editorInput" v-model="counterText" type="text"
               inputmode="numeric" maxlength="3"
               autocomplete="off" @input="onInput" @keydown="onEditorKeydown" @keyup.stop>
        <button class="counter-editor__confirm" type="submit" :disabled="!editorValid"
                title="Set number" aria-label="Set number">
          <img :src="confirmSrc" alt="">
        </button>
        <button class="counter-editor__cancel" type="button" title="Cancel" aria-label="Cancel" @click="cancelEditor">
          <img :src="cancelSrc" alt="">
        </button>
      </form>
    </section>
  </template>
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
.counter-editor__scrim { position: fixed; z-index: 29; inset: 0; display: block; pointer-events: auto; }
.counter-editor { position: fixed; z-index: 30; top: 50%; left: 50%; width: 460px; height: 270px; color: #3b2917; font-family: Georgia, serif; text-shadow: none; transform: translate(-50%, -50%); pointer-events: auto; }
.counter-editor__frame { position: absolute; inset: 0; width: 100%; height: 100%; pointer-events: none; user-select: none; }
.counter-editor form { position: absolute; inset: 0; }
.counter-editor label { position: absolute; top: 54px; right: 60px; left: 60px; color: #4a321c; font-size: 18px; }
.counter-editor input { position: absolute; top: 123px; right: 60px; left: 60px; width: 340px; padding: 4px 2px; border: 0; outline: 0; background: transparent; color: #6c2019; font: 20px Georgia, serif; caret-color: #6c2019; pointer-events: auto; }
.counter-editor button { position: absolute; bottom: 24px; width: 42px; height: 42px; padding: 0; overflow: hidden; border: 0; outline: 0; background: transparent; cursor: pointer; pointer-events: auto; }
.counter-editor button:focus-visible { outline: 1px solid #7a3d27; }
.counter-editor button img { position: absolute; pointer-events: none; user-select: none; }
.counter-editor__confirm { left: 120px; }
.counter-editor__confirm img { inset: 5px; width: 32px; height: 32px; }
.counter-editor__confirm:disabled { opacity: 0; cursor: default; pointer-events: none; }
.counter-editor__cancel { left: 267px; }
.counter-editor__cancel img { top: 2px; left: 1px; width: 40px; height: 95px; object-fit: cover; object-position: top; }
</style>

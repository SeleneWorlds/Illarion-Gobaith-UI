<script setup lang="ts">
import { onBeforeUnmount, onMounted } from 'vue';

const props = defineProps<{
  open: boolean;
  frameSrc: string;
  label: string;
  variant?: 'short' | 'long';
}>();

const emit = defineEmits<{ close: [] }>();
const close = () => emit('close');
const closeOnEscape = (event: KeyboardEvent) => {
  if (!props.open || event.key !== 'Escape') return;
  event.stopImmediatePropagation();
  close();
};

onMounted(() => {
  window.addEventListener('click', close);
  window.addEventListener('keydown', closeOnEscape);
});
onBeforeUnmount(() => {
  window.removeEventListener('click', close);
  window.removeEventListener('keydown', closeOnEscape);
});
</script>

<template>
  <menu v-if="open" class="context-menu" :class="`context-menu--${variant ?? 'short'}`" data-selene-interactive :aria-label="label" @click.stop>
    <img class="context-menu__frame" :src="frameSrc" alt="">
    <slot />
  </menu>
</template>

<style scoped>
.context-menu { position: absolute; z-index: 20; margin: 0; list-style: none; pointer-events: auto; }
.context-menu--short { width: 198px; height: 145px; padding: 25px 22px 20px; }
.context-menu--long { width: 164px; min-height: 202px; max-height: 370px; padding: 24px 20px; overflow-y: auto; scrollbar-width: thin; scrollbar-color: rgb(80 55 30 / 45%) transparent; }
.context-menu__frame { position: absolute; z-index: -1; inset: 0; width: 100%; height: 100%; pointer-events: none; }
:slotted(li) { margin: 0; padding: 0; }
:slotted(li > button) { position: relative; width: 100%; border: 0; background: transparent; color: #342515; font-family: Georgia, serif; text-align: left; cursor: pointer; }
.context-menu--short :slotted(li > button) { height: 32px; padding: 4px 12px; font-size: 14px; }
.context-menu--long :slotted(li > button) { height: 21px; padding: 1px 8px; font-size: 13px; }
:slotted(li > button:hover:not(:disabled)),
:slotted(li > button:focus-visible) { color: #8d1e18; outline: 0; }
:slotted(li > button:disabled) { color: #8b7c68; cursor: default; }
:slotted(.context-menu__separator) { height: 7px; border-top: 1px solid rgb(75 50 25 / 35%); }
</style>

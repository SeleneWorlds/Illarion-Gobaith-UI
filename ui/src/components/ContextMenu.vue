<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, useTemplateRef, watch } from 'vue';
import { useSelene } from '../selene';

defineProps<{ label: string }>();

const selene = useSelene();
const open = defineModel<boolean>('open', { required: true });
const element = useTemplateRef<HTMLElement>('element');
const layout = ref<{ width: number; height: number; paddingX: number; paddingY: number; variant: 'short' | 'long' }>();
const frameSrc = computed(() => selene.resolveAsset(
  layout.value?.variant === 'short' ? './assets/menu_short.png' : './assets/menu_long.png',
));
const menuStyle = computed(() => layout.value && ({
  width: `${layout.value.width}px`,
  height: `${layout.value.height}px`,
  padding: `${layout.value.paddingY}px ${layout.value.paddingX}px`,
}));
const close = () => { open.value = false; };
const closeOnEscape = (event: KeyboardEvent) => {
  if (!open.value || event.key !== 'Escape') return;
  event.stopImmediatePropagation();
  close();
};

const measure = async () => {
  layout.value = undefined;
  await nextTick();
  if (!open.value || !element.value) return;

  let contentWidth = 0;
  let contentHeight = 0;
  for (const item of element.value.querySelectorAll<HTMLElement>(':scope > li')) {
    if (getComputedStyle(item).display === 'none') continue;
    const button = item.querySelector<HTMLElement>(':scope > button');
    if (button) {
      contentWidth = Math.max(contentWidth, button.scrollWidth);
      contentHeight += Math.ceil(button.getBoundingClientRect().height) + 5;
    } else {
      contentWidth = Math.max(contentWidth, item.scrollWidth);
      contentHeight += Math.ceil(item.getBoundingClientRect().height);
    }
  }

  // Match the integer arithmetic in the legacy client.
  const paddingX = Math.floor(contentWidth * 0.3);
  const paddingY = Math.floor(contentHeight * 0.3);
  const width = contentWidth + 2 * paddingX;
  const height = contentHeight + 2 * paddingY;
  layout.value = {
    width,
    height,
    paddingX,
    paddingY,
    variant: width / height > 1.1 ? 'short' : 'long',
  };
};

onMounted(() => {
  window.addEventListener('click', close);
  window.addEventListener('keydown', closeOnEscape);
  void document.fonts.ready.then(measure);
});
onBeforeUnmount(() => {
  window.removeEventListener('click', close);
  window.removeEventListener('keydown', closeOnEscape);
});
watch(open, value => {
  if (value) void measure();
  else layout.value = undefined;
});
</script>

<template>
  <menu v-if="open" ref="element" class="menu" :class="{ measuring: !layout }" :style="menuStyle"
        data-selene-interactive :aria-label="label" @click.stop>
    <img class="frame" :src="frameSrc" alt="">
    <slot />
  </menu>
</template>

<style scoped>
.menu { position: absolute; z-index: 20; box-sizing: border-box; margin: 0; list-style: none; pointer-events: auto; }
.measuring { width: max-content; height: auto; padding: 0; visibility: hidden; }
.measuring :slotted(li > button) { width: max-content; }
.frame { position: absolute; z-index: -1; inset: 0; width: 100%; height: 100%; pointer-events: none; }
:slotted(li) { margin: 0; padding: 0; }
:slotted(li > button) { position: relative; width: 100%; border: 0; background: transparent; color: #342515; font-family: Georgia, serif; text-align: left; cursor: pointer; }
:slotted(li > button) { height: auto; padding: 0; font-size: 14px; line-height: normal; }
:slotted(li > button:hover:not(:disabled)),
:slotted(li > button:focus-visible) { color: #8d1e18; outline: 0; }
:slotted(li > button:disabled) { color: #8b7c68; cursor: default; }
:slotted(.separator) { height: 7px; border-top: 1px solid rgb(75 50 25 / 35%); }
</style>

<script setup lang="ts">
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  provide,
  reactive,
  ref,
  useTemplateRef,
  type Component,
} from 'vue';
import { menuControllerKey, type MenuOptions } from '../overlays';
import { useUiAssetSrc } from '../composables/useClientAsset';

const element = useTemplateRef<HTMLElement>('element');
const component = ref<Component>();
const componentProps = ref<Record<string, unknown>>({});
const options = ref<MenuOptions>();
const layout = ref<{ width: number; height: number; paddingX: number; paddingY: number; variant: 'short' | 'long' }>();
const position = reactive({ left: 0, top: 0 });
const frameSrc = useUiAssetSrc(() => layout.value?.variant === 'short' ? 'menu_short.png' : 'menu_long.png');
const menuStyle = computed(() => ({
  left: `${position.left}px`,
  top: `${position.top}px`,
  ...(layout.value && {
    width: `${layout.value.width}px`,
    height: `${layout.value.height}px`,
    padding: `${layout.value.paddingY}px ${layout.value.paddingX}px`,
  }),
}));
let resolveResult: ((result: unknown) => void) | undefined;
const finish = (result?: unknown) => {
  const resolve = resolveResult;
  resolveResult = undefined;
  component.value = undefined;
  componentProps.value = {};
  options.value = undefined;
  layout.value = undefined;
  resolve?.(result);
};
const close = () => finish();
const measure = async () => {
  await nextTick();
  if (!options.value || !element.value) {
    return;
  }
  let contentWidth = 0;
  let contentHeight = 0;
  for (const item of element.value.querySelectorAll<HTMLElement>(':scope > li')) {
    if (getComputedStyle(item).display === 'none') {
      continue;
    }
    const button = item.querySelector<HTMLElement>(':scope > button');
    contentWidth = Math.max(contentWidth, button?.scrollWidth ?? item.scrollWidth);
    contentHeight += button
      ? Math.ceil(button.getBoundingClientRect().height) + 5
      : Math.ceil(item.getBoundingClientRect().height);
  }
  const paddingX = Math.floor(contentWidth * 0.3);
  const paddingY = Math.floor(contentHeight * 0.3);
  const width = contentWidth + 2 * paddingX;
  const height = contentHeight + 2 * paddingY;
  layout.value = { width, height, paddingX, paddingY, variant: width / height > 1.1 ? 'short' : 'long' };
  await nextTick();
  const container = element.value?.offsetParent;
  if (!(container instanceof HTMLElement) || !options.value) {
    return;
  }
  const containerRect = container.getBoundingClientRect();
  const scale = containerRect.width / container.offsetWidth;
  const anchorRect = options.value.anchor?.getBoundingClientRect();
  const x = options.value.position?.x ?? anchorRect?.left ?? containerRect.left;
  const y = options.value.position?.y ?? anchorRect?.bottom ?? containerRect.top;
  position.left = Math.min(container.offsetWidth - width, Math.max(0, (x - containerRect.left) / scale));
  position.top = Math.min(container.offsetHeight - height, Math.max(0, (y - containerRect.top) / scale));
};
const open = <TResult,>(
  menuComponent: Component,
  props: Record<string, unknown>,
  menuOptions: MenuOptions,
): Promise<TResult | undefined> => {
  finish();
  component.value = menuComponent;
  componentProps.value = props;
  options.value = menuOptions;
  layout.value = undefined;
  void measure();
  return new Promise((resolve) => {
    resolveResult = resolve as (result: unknown) => void;
  });
};
const closeOnEscape = (event: KeyboardEvent) => {
  if (!options.value || event.key !== 'Escape') {
    return;
  }
  event.stopImmediatePropagation();
  close();
};
provide(menuControllerKey, {
  open,
  close,
  isOpen: (value) => Boolean(component.value && (!value || component.value === value)),
});
onMounted(() => {
  window.addEventListener('click', close);
  window.addEventListener('keydown', closeOnEscape);
});
onBeforeUnmount(() => {
  window.removeEventListener('click', close);
  window.removeEventListener('keydown', closeOnEscape);
  close();
});
</script>

<template>
  <slot />
  <menu
    v-if="options"
    ref="element"
    class="menu-overlay"
    :class="{ measuring: !layout }"
    :style="menuStyle"
    data-selene-interactive
    :aria-label="options.label"
    @click.stop
  >
    <img class="frame" :src="frameSrc" alt="" />
    <component :is="component" v-bind="componentProps" @result="finish" />
  </menu>
</template>

<style scoped>
.menu-overlay {
  position: absolute;
  z-index: 20;
  box-sizing: border-box;
  margin: 0;
  list-style: none;
  pointer-events: auto;
}
.measuring {
  width: max-content;
  height: auto;
  padding: 0;
  visibility: hidden;
}
.measuring :deep(li > button) {
  width: max-content;
}
.frame {
  position: absolute;
  z-index: -1;
  inset: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
}
.menu-overlay :deep(li) {
  margin: 0;
  padding: 0;
}
.menu-overlay :deep(li > button) {
  position: relative;
  width: 100%;
  height: auto;
  padding: 0;
  border: 0;
  background: transparent;
  color: #342515;
  font:
    14px/normal Georgia,
    serif;
  text-align: left;
  cursor: pointer;
}
.menu-overlay :deep(li > button:hover:not(:disabled)),
.menu-overlay :deep(li > button:focus-visible) {
  color: #8d1e18;
  outline: 0;
}
.menu-overlay :deep(li > button:disabled) {
  color: #8b7c68;
  cursor: default;
}
.menu-overlay :deep(.separator) {
  height: 7px;
  border-top: 1px solid rgb(75 50 25 / 35%);
}
</style>

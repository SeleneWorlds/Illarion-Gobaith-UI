<script setup lang="ts">
import { nextTick, onUnmounted, provide, reactive, useTemplateRef, watch } from 'vue';
import { tooltipControllerKey, type TooltipOptions } from '../overlays';
import { useInventoryStore } from '../stores/inventory';

const inventory = useInventoryStore();
const tooltipElement = useTemplateRef<HTMLElement>('tooltipElement');
const tooltip = reactive({ options: undefined as TooltipOptions | undefined, left: 0, top: 0, visible: false });
let hideTimeout: number | undefined;
let fadeTimeout: number | undefined;
let updateId = 0;

const clearTimers = () => {
  if (hideTimeout !== undefined) {
    window.clearTimeout(hideTimeout);
  }
  if (fadeTimeout !== undefined) {
    window.clearTimeout(fadeTimeout);
  }
  hideTimeout = undefined;
  fadeTimeout = undefined;
};
const hide = () => {
  updateId += 1;
  clearTimers();
  tooltip.visible = false;
  fadeTimeout = window.setTimeout(() => {
    tooltip.options = undefined;
  }, 400);
};
const show = async (options: TooltipOptions) => {
  const currentUpdateId = ++updateId;
  clearTimers();
  tooltip.visible = false;
  tooltip.options = options;
  await nextTick();
  if (currentUpdateId !== updateId || !options.anchor.isConnected || !tooltipElement.value) {
    return;
  }
  const container = tooltipElement.value.offsetParent;
  if (!(container instanceof HTMLElement)) {
    return;
  }
  const anchorRect = options.anchor.getBoundingClientRect();
  const containerRect = container.getBoundingClientRect();
  const scale = containerRect.width / container.offsetWidth;
  const halfWidth = (tooltipElement.value.offsetWidth * scale) / 2;
  const halfHeight = (tooltipElement.value.offsetHeight * scale) / 2;
  const desiredX = anchorRect.left + anchorRect.width / 2;
  const desiredY = anchorRect.top - halfHeight - (options.offset ?? 4) * scale;
  const boundedX = Math.min(window.innerWidth - halfWidth, Math.max(halfWidth, desiredX));
  const boundedY = Math.min(window.innerHeight - halfHeight, Math.max(halfHeight, desiredY));
  tooltip.left = (boundedX - containerRect.left) / scale;
  tooltip.top = (boundedY - containerRect.top) / scale;
  requestAnimationFrame(() => {
    if (currentUpdateId === updateId) {
      tooltip.visible = true;
    }
  });
  const duration =
    options.duration ?? 2500 + (5000 * [options.title, options.description].filter(Boolean).join('\n').length) / 80;
  hideTimeout = window.setTimeout(hide, duration);
};

provide(tooltipControllerKey, { show, hide });
watch(inventory.tooltipResponse, (response) => {
  if (!response?.tooltip) {
    hide();
    return;
  }
  const anchor = document
    .querySelector<HTMLElement>(
      `[data-inventory-slot-button][data-view-id="${response.slot.viewId}"][data-slot-id="${response.slot.slotId}"]`,
    )
    ?.closest<HTMLElement>('[data-inventory-slot]');
  if (anchor) {
    void show({ anchor, title: response.tooltip.name ?? '', description: response.tooltip.description });
  }
});
onUnmounted(clearTimers);
</script>

<template>
  <slot />
  <span
    v-if="tooltip.options"
    ref="tooltipElement"
    class="tooltip-overlay"
    :class="{ visible: tooltip.visible }"
    :style="{ left: `${tooltip.left}px`, top: `${tooltip.top}px` }"
    role="tooltip"
  >
    <span>{{ tooltip.options.title }}</span>
    <span v-if="tooltip.options.description">{{ tooltip.options.description }}</span>
  </span>
</template>

<style scoped>
.tooltip-overlay {
  position: absolute;
  z-index: 30;
  display: block;
  width: max-content;
  max-width: 280px;
  padding: 5px 10px;
  border: 0;
  border-radius: 9px;
  background: rgb(0 0 0 / 50%);
  color: #fff;
  font:
    14px Arial,
    Helvetica,
    sans-serif;
  line-height: normal;
  text-align: center;
  white-space: pre-line;
  opacity: 0;
  transform: translate(-50%, -50%);
  transition: opacity 400ms linear;
  pointer-events: none;
}
.tooltip-overlay.visible {
  opacity: 1;
}
.tooltip-overlay span {
  display: block;
}
</style>

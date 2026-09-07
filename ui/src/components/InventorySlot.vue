<script setup lang="ts">
// TODO deslop file
import { computed, nextTick, onMounted, onUnmounted, reactive, ref, useTemplateRef, watch } from 'vue';
import { resolveClientAsset } from '../clientAssets';
import type { Coordinate, SelenePointerEvent } from '../selene';
import { useSelene } from '../selene';
import type { InventorySlotDefinition, InventoryTooltip } from '../inventory';
import { inventorySlotKey } from '../inventory';
import { useInventoryStore } from '../stores/inventory';
import ContextMenu from './ContextMenu.vue';
import SeleneVisual from './SeleneVisual.vue';

const props = defineProps<{ slot: InventorySlotDefinition }>();
const selene = useSelene();
const inventory = useInventoryStore();
const key = computed(() => inventorySlotKey(props.slot));
const item = computed(() => inventory.items[key.value]);
const element = useTemplateRef<HTMLElement>('element');
const tooltipElement = useTemplateRef<HTMLElement>('tooltipElement');
const hoverBackground = ref('none');
const menuOpen = ref(false);
const menu = reactive({ left: 0, top: 0 });
const tooltip = reactive({ value: undefined as InventoryTooltip | undefined, left: 39, top: -17.5, visible: false });
const dragPreview = reactive({ visible: false, left: 0, top: 0 });
const using = ref(false);
let draggedCoordinate: Coordinate | undefined;
let pointerDown = { x: 0, y: 0 };
let dragged = false;
let tooltipTimeout: number | undefined;
let tooltipFadeTimeout: number | undefined;
const inputUnsubscribers: Array<() => void> = [];

const hitBands = Array.from({ length: 20 }, (_, index) => {
  const top = index * 2;
  const height = Math.min(2, 39 - top);
  const distanceFromCenter = Math.abs(19.5 - (top + height / 2));
  const left = Math.floor(distanceFromCenter * 2);
  return { top, left, width: 78 - left * 2, height };
});

const isInWorldViewport = (x: number, y: number) => x >= 0 && x < 839 && y >= 0 && y < 419;
const slotAt = (x: number, y: number): InventorySlotDefinition | undefined => {
  const candidate = document.elementsFromPoint(x, y)
    .map(node => node instanceof HTMLElement ? node.closest<HTMLElement>('.inventory-slot__button') : null)
    .find(node => node !== null);
  if (!(candidate instanceof HTMLElement)) return undefined;
  const rect = candidate.getBoundingClientRect();
  const normalizedX = Math.abs(x - (rect.left + rect.width / 2)) / (rect.width / 2);
  const normalizedY = Math.abs(y - (rect.top + rect.height / 2)) / (rect.height / 2);
  if (normalizedX + normalizedY > 1) return undefined;
  const viewId = candidate.dataset.viewId;
  const slotId = Number(candidate.dataset.slotId);
  return (viewId === 'equipment' || viewId === 'belt') && Number.isInteger(slotId)
    ? { viewId, slotId }
    : undefined;
};
const clearTooltipTimers = () => {
  if (tooltipTimeout !== undefined) window.clearTimeout(tooltipTimeout);
  if (tooltipFadeTimeout !== undefined) window.clearTimeout(tooltipFadeTimeout);
  tooltipTimeout = undefined;
  tooltipFadeTimeout = undefined;
};
const hideTooltip = () => {
  tooltip.visible = false;
  tooltipFadeTimeout = window.setTimeout(() => { tooltip.value = undefined; }, 400);
};
const updateTooltip = async () => {
  const response = inventory.tooltipResponse.value;
  if (!response || inventorySlotKey(response.slot) !== key.value) return;
  tooltip.value = response.tooltip;
  if (!tooltip.value) return;
  clearTooltipTimers();
  await nextTick();
  if (!element.value || !tooltipElement.value) return;
  const rect = element.value.getBoundingClientRect();
  const scale = rect.width / element.value.offsetWidth;
  const halfWidth = tooltipElement.value.offsetWidth * scale / 2;
  const halfHeight = tooltipElement.value.offsetHeight * scale / 2;
  const desiredX = rect.left + 39 * scale;
  const desiredY = rect.top - 17.5 * scale;
  const boundedX = Math.min(window.innerWidth - halfWidth, Math.max(halfWidth, desiredX));
  const boundedY = Math.min(window.innerHeight - halfHeight, Math.max(halfHeight, desiredY));
  tooltip.left = (boundedX - rect.left) / scale;
  tooltip.top = (boundedY - rect.top) / scale;
  requestAnimationFrame(() => { tooltip.visible = true; });
  const text = [tooltip.value.name, tooltip.value.description].filter(Boolean).join('\n');
  tooltipTimeout = window.setTimeout(hideTooltip, 2500 + 5000 * text.length / 80);
};
const lookAt = () => {
  if (!item.value || dragged) return;
  tooltip.value = undefined;
  tooltip.visible = false;
  clearTooltipTimers();
  inventory.lookAt(props.slot);
};
const startDrag = (event: MouseEvent) => {
  if (event.button !== 0 || !item.value) return;
  pointerDown = { x: event.clientX, y: event.clientY };
  dragged = false;
  dragPreview.visible = true;
  if (event.shiftKey) using.value = true;
  moveDragPreview(event);
  event.preventDefault();
};
const moveDragPreview = (event: MouseEvent) => {
  if (!dragPreview.visible || !element.value) return;
  dragged ||= Math.abs(event.clientX - pointerDown.x) + Math.abs(event.clientY - pointerDown.y) > 3;
  const rect = element.value.getBoundingClientRect();
  const scale = rect.width / element.value.offsetWidth;
  dragPreview.left = (event.clientX - rect.left) / scale;
  dragPreview.top = (event.clientY - rect.top) / scale;
};
const endGameDrag = ({ clientX, clientY, coordinate }: SelenePointerEvent) => {
  const target = slotAt(clientX, clientY);
  if (dragPreview.visible) {
    if (target && inventorySlotKey(target) !== key.value) inventory.moveSlotToSlot(props.slot, target, inventory.counter.value);
    else if (!target && isInWorldViewport(clientX, clientY)) inventory.moveSlotToCoordinate(props.slot, coordinate, inventory.counter.value);
    dragPreview.visible = false;
  } else if (draggedCoordinate && target && inventorySlotKey(target) === key.value) {
    inventory.moveCoordinateToSlot(draggedCoordinate, props.slot, inventory.counter.value);
  }
  draggedCoordinate = undefined;
};
const startWorldDrag = ({ button, shiftKey, clientX, clientY, coordinate }: SelenePointerEvent) => {
  if (button === 0 && !shiftKey && isInWorldViewport(clientX, clientY)) draggedCoordinate = coordinate;
};
const openMenu = (event: MouseEvent) => {
  if (!item.value || !element.value) return;
  const rect = element.value.getBoundingClientRect();
  const scale = rect.width / element.value.offsetWidth;
  const parent = element.value.offsetParent;
  const parentWidth = parent instanceof HTMLElement ? parent.offsetWidth : 1024;
  const parentHeight = parent instanceof HTMLElement ? parent.offsetHeight : 768;
  menu.left = Math.min(parentWidth - 164 - element.value.offsetLeft, Math.max(-element.value.offsetLeft, (event.clientX - rect.left) / scale));
  menu.top = Math.min(parentHeight - 202 - element.value.offsetTop, Math.max(-element.value.offsetTop, (event.clientY - rect.top) / scale));
  menuOpen.value = true;
};
const sendAction = (action: 'open' | 'use' | 'drop') => {
  if (action === 'open') inventory.openContainer(props.slot, inventory.counter.value);
  if (action === 'use') inventory.use(props.slot, inventory.counter.value);
  if (action === 'drop') inventory.dropInFront(props.slot, inventory.counter.value);
  menuOpen.value = false;
};
const useWith = () => { using.value = true; menuOpen.value = false; };
const finishUse = (event: KeyboardEvent) => {
  if (event.key !== 'Shift' || !using.value) return;
  inventory.use(props.slot);
  using.value = false;
};
const adjustCounter = (event: WheelEvent) => {
  event.preventDefault();
  inventory.setCounter(inventory.counter.value + (event.deltaY < 0 ? 1 : -1));
};

onMounted(() => {
  void resolveClientAsset(selene, 'client/textures/illarion/ui/inv_slot-7.png')
    .then(url => { hoverBackground.value = `url("${url}")`; })
    .catch(error => console.warn('[Illarion inventory]', error));
  window.addEventListener('mousemove', moveDragPreview, true);
  window.addEventListener('keyup', finishUse, true);
  inputUnsubscribers.push(selene.input.onPointerDown(startWorldDrag));
  inputUnsubscribers.push(selene.input.onPointerUp(endGameDrag));
});
onUnmounted(() => {
  clearTooltipTimers();
  window.removeEventListener('mousemove', moveDragPreview, true);
  window.removeEventListener('keyup', finishUse, true);
  inputUnsubscribers.splice(0).forEach(release => release());
});

watch(inventory.tooltipResponse, updateTooltip);
watch(item, value => {
  if (value) return;
  clearTooltipTimers();
  tooltip.value = undefined;
  menuOpen.value = false;
  using.value = false;
  dragPreview.visible = false;
});
</script>

<template>
  <div ref="element" class="inventory-slot">
    <button type="button" class="inventory-slot__button" :data-view-id="slot.viewId" :data-slot-id="slot.slotId"
            :style="{ '--slot-background': `url(${selene.resolveAsset('./assets/inv_slot-0.png')})`, '--slot-hover-background': hoverBackground }"
            :aria-label="`${slot.viewId} slot ${slot.slotId}`" @mousedown="startDrag" @click="lookAt"
            @contextmenu.prevent.stop="openMenu" @wheel="adjustCounter">
      <span v-for="band in hitBands" :key="band.top" class="hit" data-selene-interactive
            :style="{ top: `${band.top}px`, left: `${band.left}px`, width: `${band.width}px`, height: `${band.height}px` }" />
      <SeleneVisual v-if="item" class="item" :identifier="item.visual" :seed="key" without-offset />
      <span v-if="item && item.count > 1" class="count">{{ item.count }}</span>
    </button>
    <img v-if="using" class="using" :src="selene.resolveAsset('./assets/mark_use.png')" alt="Item currently being used">
    <span v-if="tooltip.value" ref="tooltipElement" class="tooltip" :class="{ visible: tooltip.visible }"
          :style="{ left: `${tooltip.left}px`, top: `${tooltip.top}px` }" role="tooltip">
      <span>{{ tooltip.value.name }}</span>
      <span v-if="tooltip.value.description">{{ tooltip.value.description }}</span>
    </span>
    <span v-if="dragPreview.visible && item" class="drag-preview" :style="{ left: `${dragPreview.left}px`, top: `${dragPreview.top}px` }">
      <SeleneVisual :identifier="item.visual" :seed="key" without-offset />
    </span>
    <ContextMenu v-model:open="menuOpen" class="menu" label="Item actions" :style="{ left: `${menu.left}px`, top: `${menu.top}px` }">
      <li><button type="button" :disabled="!item?.container" @click="sendAction('open')">Open</button></li>
      <li><button type="button" @click="lookAt(); menuOpen = false">Look at</button></li>
      <li><button type="button" @click="sendAction('use')">Use</button></li>
      <li><button type="button" @click="useWith">Use with</button></li>
      <li><button type="button" @click="sendAction('drop')">Drop</button></li>
    </ContextMenu>
  </div>
</template>

<style scoped>
.inventory-slot { position: absolute; width: 78px; height: 39px; pointer-events: none; }
.inventory-slot__button { position: absolute; inset: 0; width: 78px; height: 39px; margin: 0; padding: 0; overflow: hidden; border: 0; clip-path: polygon(50% 0, 100% 50%, 50% 100%, 0 50%); background: var(--slot-background) no-repeat; cursor: grab; pointer-events: none; }
.inventory-slot__button:has(.hit:hover) { background-image: var(--slot-hover-background); }
.inventory-slot__button:active { cursor: grabbing; }
.inventory-slot__button:focus-visible { outline: 1px solid #b7d9ba; outline-offset: -2px; }
.hit { position: absolute; z-index: 2; display: block; pointer-events: auto; }
.item { position: absolute; inset: 0; display: block; user-select: none; pointer-events: none; }
.count { position: absolute; z-index: 3; right: 17px; bottom: 7px; color: white; font: bold 12px Arial, sans-serif; line-height: 1; text-shadow: -1px -1px #000, 1px -1px #000, -1px 1px #000, 1px 1px #000; pointer-events: none; }
.using { position: absolute; z-index: 4; top: 19.5px; left: 39px; width: 139px; height: 71px; transform: translate(-50%, -50%); pointer-events: none; }
.tooltip { position: absolute; z-index: 30; display: block; width: max-content; max-width: 280px; padding: 5px 10px; border: 0; border-radius: 9px; background: rgb(0 0 0 / 50%); color: #fff; font: 14px Arial, Helvetica, sans-serif; line-height: normal; text-align: center; white-space: pre-line; opacity: 0; transform: translate(-50%, -50%); transition: opacity 400ms linear; pointer-events: none; }
.tooltip.visible { opacity: 1; }
.tooltip span { display: block; }
.menu { position: absolute; }
.drag-preview { position: absolute; z-index: 10; display: block; width: 0; height: 0; opacity: .85; user-select: none; pointer-events: none; }
</style>

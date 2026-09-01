<script setup lang="ts">
import { nextTick, onMounted, onUnmounted, reactive, ref } from 'vue';
import type { ClientNetworkPayload, Coordinate, SelenePointerEvent, SeleneUiApi } from '../selene';
import ContextMenu from './ContextMenu.vue';
import SeleneVisual from './SeleneVisual.vue';

type ViewId = 'equipment' | 'belt';
interface Slot { viewId: ViewId; slotId: number }
interface HitBand { top: number; left: number; width: number; height: number }
interface InventoryItem { visual: string; count: number; container: boolean }
interface Tooltip { name?: string; description?: string }
const props = defineProps<{ selene: SeleneUiApi }>();
const counter = defineModel<number>('counter', { required: true });
const equipmentSlots: Slot[] = Array.from({ length: 12 }, (_, slotId) => ({ viewId: 'equipment', slotId }));
const beltSlots: Slot[] = Array.from({ length: 6 }, (_, index) => ({ viewId: 'belt', slotId: index + 12 }));
const slots = [...equipmentSlots, ...beltSlots];
const hitBands: HitBand[] = Array.from({ length: 20 }, (_, index) => {
  const top = index * 2;
  const height = Math.min(2, 39 - top);
  const distanceFromCenter = Math.abs(19.5 - (top + height / 2));
  const left = Math.floor(distanceFromCenter * 2);
  return { top, left, width: 78 - left * 2, height };
});
const items = reactive<Record<string, InventoryItem>>({});
const inventoryElement = ref<HTMLElement>();
const slotElements = ref<HTMLElement[]>([]);
const tooltipElement = ref<HTMLElement>();
const slotHoverBackground = ref('none');
const dragPreview = reactive({ visual: '', seed: '', left: 0, top: 0 });
const menu = reactive({ slot: undefined as Slot | undefined, left: 0, top: 0 });
const tooltip = reactive({ slot: undefined as Slot | undefined, value: undefined as Tooltip | undefined, left: 0, top: 0, visible: false });
const useMarker = reactive({ slot: undefined as Slot | undefined, left: 0, top: 0 });
let clientManifest: Promise<Record<string, string>> | undefined;
let draggedSlot: Slot | undefined;
let draggedCoordinate: Coordinate | undefined;
let pointerDown = { x: 0, y: 0 };
let dragged = false;
const unsubscribers: Array<() => void> = [];
const inputUnsubscribers: Array<() => void> = [];
let tooltipTimeout: number | undefined;
let tooltipFadeTimeout: number | undefined;

const key = ({ viewId, slotId }: Slot) => `${viewId}:${slotId}`;
const isInWorldViewport = (x: number, y: number) => x >= 0 && x < 839 && y >= 0 && y < 419;
const resolveClientAsset = async (path: string) => {
  const base = new URL(props.selene.resolveAsset('./'));
  if (!clientManifest) {
    clientManifest = fetch(new URL('/client/asset-manifest.json', base))
      .then(response => {
        if (!response.ok) throw new Error(`Could not load client asset manifest: ${response.status}`);
        return response.json() as Promise<{ assets?: Record<string, string> }>;
      })
      .then(manifest => manifest.assets ?? {});
  }
  const publicPath = (await clientManifest)[path];
  if (!publicPath) throw new Error(`Client asset is missing: ${path}`);
  return new URL(publicPath, base).href;
};
const payloadString = (payload: ClientNetworkPayload, field: string) =>
  typeof payload[field] === 'string' ? payload[field] as string : undefined;
const payloadNumber = (payload: ClientNetworkPayload, field: string) =>
  typeof payload[field] === 'number' && Number.isInteger(payload[field]) ? payload[field] as number : undefined;

const updateSlot = (payload: ClientNetworkPayload) => {
  const viewId = payloadString(payload, 'viewId');
  const slotId = payloadNumber(payload, 'slotId');
  if ((viewId !== 'equipment' && viewId !== 'belt') || slotId === undefined) return;
  const slotKey = key({ viewId, slotId });
  const item = payload.item;
  const itemPayload = item && typeof item === 'object' ? item as ClientNetworkPayload : undefined;
  const visual = typeof itemPayload?.visual === 'string'
    ? itemPayload.visual
    : undefined;
  if (!visual) {
    delete items[slotKey];
    if (tooltip.slot && key(tooltip.slot) === slotKey) {
      clearTooltipTimers();
      tooltip.value = undefined;
    }
    if (menu.slot && key(menu.slot) === slotKey) menu.slot = undefined;
    if (useMarker.slot && key(useMarker.slot) === slotKey) useMarker.slot = undefined;
    return;
  }
  items[slotKey] = {
    visual,
    count: typeof itemPayload?.count === 'number' ? Math.max(1, Math.round(itemPayload.count)) : 1,
    container: itemPayload?.container === true,
  };
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
const tooltipText = () => [tooltip.value?.name, tooltip.value?.description].filter(Boolean).join('\n');
const updateTooltip = async (payload: ClientNetworkPayload) => {
  const viewId = payloadString(payload, 'viewId');
  const slotId = payloadNumber(payload, 'slotId');
  if (!tooltip.slot || viewId !== tooltip.slot.viewId || slotId !== tooltip.slot.slotId) return;
  const value = payload.tooltip;
  tooltip.value = value && typeof value === 'object' ? value as Tooltip : undefined;
  if (!tooltip.value) return;
  clearTooltipTimers();
  await nextTick();
  const width = tooltipElement.value?.offsetWidth ?? 0;
  const height = tooltipElement.value?.offsetHeight ?? 0;
  // The inventory starts at x=846 in the legacy 1024x768 HUD.
  tooltip.left = Math.min(178 - width / 2, Math.max(-846 + width / 2, tooltip.left));
  tooltip.top = Math.min(768 - height / 2, Math.max(height / 2, tooltip.top));
  requestAnimationFrame(() => { tooltip.visible = true; });
  const displayTime = 2500 + 5000 * tooltipText().length / 80;
  tooltipTimeout = window.setTimeout(hideTooltip, displayTime);
};
const slotAt = (x: number, y: number) => {
  const element = slotElements.value.find(candidate => {
    const rect = candidate.getBoundingClientRect();
    if (x < rect.left || x > rect.right || y < rect.top || y > rect.bottom) return false;
    const normalizedX = Math.abs(x - (rect.left + rect.width / 2)) / (rect.width / 2);
    const normalizedY = Math.abs(y - (rect.top + rect.height / 2)) / (rect.height / 2);
    return normalizedX + normalizedY <= 1;
  });
  if (!element) return undefined;
  const viewId = element.dataset.viewId;
  const slotId = Number(element.dataset.slotId);
  return (viewId === 'equipment' || viewId === 'belt') && Number.isInteger(slotId)
    ? { viewId, slotId } as Slot
    : undefined;
};
const startDrag = (slot: Slot, event: MouseEvent) => {
  if (event.button !== 0 || !items[key(slot)]) return;
  draggedSlot = slot;
  if (event.shiftKey) setUseMarker(slot);
  pointerDown = { x: event.clientX, y: event.clientY };
  dragged = false;
  dragPreview.visual = items[key(slot)].visual;
  dragPreview.seed = key(slot);
  moveDragPreview(event);
  event.preventDefault();
};
const setUseMarker = (slot: Slot) => {
  const element = slotElements.value.find(candidate => candidate.dataset.viewId === slot.viewId
    && Number(candidate.dataset.slotId) === slot.slotId);
  useMarker.slot = slot;
  useMarker.left = (element?.offsetLeft ?? 0) + 39;
  useMarker.top = (element?.offsetTop ?? 0) + 19.5;
};
const moveDragPreview = (event: MouseEvent) => {
  if (!draggedSlot || !dragPreview.visual || !inventoryElement.value) return;
  dragged ||= Math.abs(event.clientX - pointerDown.x) + Math.abs(event.clientY - pointerDown.y) > 3;
  const inventoryRect = inventoryElement.value.getBoundingClientRect();
  const scale = inventoryRect.width / inventoryElement.value.offsetWidth;
  dragPreview.left = (event.clientX - inventoryRect.left) / scale;
  dragPreview.top = (event.clientY - inventoryRect.top) / scale;
};
const endGameDrag = ({ clientX, clientY, coordinate }: SelenePointerEvent) => {
  const target = slotAt(clientX, clientY);
  if (draggedSlot && target && key(target) !== key(draggedSlot)) {
    props.selene.network.sendToServer('illarion:move_slot_to_slot', {
      fromViewId: draggedSlot.viewId,
      fromSlotId: draggedSlot.slotId,
      toViewId: target.viewId,
      toSlotId: target.slotId,
      count: counter.value,
    });
  } else if (draggedSlot && !target && isInWorldViewport(clientX, clientY)) {
    props.selene.network.sendToServer('illarion:move_slot_to_coordinate', {
      fromViewId: draggedSlot.viewId,
      fromSlotId: draggedSlot.slotId,
      x: coordinate.x,
      y: coordinate.y,
      z: coordinate.z,
      count: counter.value,
    });
  } else if (draggedCoordinate && target) {
    props.selene.network.sendToServer('illarion:move_coordinate_to_slot', {
      fromX: draggedCoordinate.x,
      fromY: draggedCoordinate.y,
      fromZ: draggedCoordinate.z,
      toViewId: target.viewId,
      toSlotId: target.slotId,
      count: counter.value,
    });
  }
  draggedSlot = undefined;
  draggedCoordinate = undefined;
  dragPreview.visual = '';
};
const lookAt = (slot: Slot) => {
  if (!items[key(slot)] || dragged) return;
  const element = slotElements.value.find(candidate => candidate.dataset.viewId === slot.viewId
    && Number(candidate.dataset.slotId) === slot.slotId);
  tooltip.slot = slot;
  tooltip.value = undefined;
  tooltip.visible = false;
  clearTooltipTimers();
  tooltip.left = (element?.offsetLeft ?? 0) + 39;
  tooltip.top = (element?.offsetTop ?? 0) + 19.5 - 37;
  props.selene.network.sendToServer('illarion:look_at_slot', { ...slot });
};
const openMenu = (slot: Slot, event: MouseEvent) => {
  if (!items[key(slot)] || !inventoryElement.value) return;
  const rect = inventoryElement.value.getBoundingClientRect();
  const scale = rect.width / inventoryElement.value.offsetWidth;
  menu.slot = slot;
  menu.left = Math.min(178 - 164, Math.max(0, (event.clientX - rect.left) / scale));
  menu.top = Math.min(768 - 202, Math.max(0, (event.clientY - rect.top) / scale));
};
const sendSlotAction = (payloadId: string) => {
  if (!menu.slot) return;
  props.selene.network.sendToServer(payloadId, { ...menu.slot, count: counter.value });
  menu.slot = undefined;
};
const useWith = () => {
  if (!menu.slot) return;
  setUseMarker(menu.slot);
  menu.slot = undefined;
};
const adjustCounter = (event: WheelEvent) => {
  event.preventDefault();
  counter.value = Math.min(250, Math.max(1, counter.value + (event.deltaY < 0 ? 1 : -1)));
};
const startWorldDrag = ({ button, shiftKey, clientX, clientY, coordinate }: SelenePointerEvent) => {
  if (button !== 0 || shiftKey || !isInWorldViewport(clientX, clientY)) return;
  draggedCoordinate = coordinate;
};
const finishUse = (event: KeyboardEvent) => {
  if (event.key !== 'Shift' || !useMarker.slot) return;
  props.selene.network.sendToServer('illarion:use_slot', {
    viewId: useMarker.slot.viewId,
    slotId: useMarker.slot.slotId,
  });
  useMarker.slot = undefined;
};

onMounted(() => {
  unsubscribers.push(props.selene.network.onPayload('illarion:update_slot', updateSlot));
  unsubscribers.push(props.selene.network.onPayload('illarion:look_at_slot', updateTooltip));
  void resolveClientAsset('client/textures/illarion/ui/inv_slot-7.png')
    .then(url => { slotHoverBackground.value = `url("${url}")`; })
    .catch(error => console.warn('[Illarion inventory]', error));
  window.addEventListener('mousemove', moveDragPreview, true);
  inputUnsubscribers.push(props.selene.input.onPointerDown(startWorldDrag));
  inputUnsubscribers.push(props.selene.input.onPointerUp(endGameDrag));
  window.addEventListener('keyup', finishUse, true);
});
onUnmounted(() => {
  clearTooltipTimers();
  unsubscribers.splice(0).forEach(release => release());
  window.removeEventListener('mousemove', moveDragPreview, true);
  inputUnsubscribers.splice(0).forEach(release => release());
  window.removeEventListener('keyup', finishUse, true);
});
</script>

<template>
  <section ref="inventoryElement" class="inventory" aria-label="Equipment and inventory slots">
    <button v-for="slot in slots" :key="key(slot)" ref="slotElements" type="button"
            :class="['slot', `${slot.viewId}-${slot.slotId}`]"
            :data-view-id="slot.viewId" :data-slot-id="slot.slotId"
            :aria-label="`${slot.viewId} slot ${slot.slotId}`" @mousedown="startDrag(slot, $event)"
            @click="lookAt(slot)" @contextmenu.prevent.stop="openMenu(slot, $event)" @wheel="adjustCounter">
      <span v-for="band in hitBands" :key="band.top" class="slot__hit" data-selene-interactive
            :style="{ top: `${band.top}px`, left: `${band.left}px`, width: `${band.width}px`, height: `${band.height}px` }" />
      <SeleneVisual v-if="items[key(slot)]" class="slot__item" :selene="selene"
                    :identifier="items[key(slot)].visual" :seed="key(slot)" without-offset />
      <span v-if="items[key(slot)]?.count > 1" class="slot__count">{{ items[key(slot)].count }}</span>
    </button>
    <img v-if="useMarker.slot" class="inventory__using" :src="selene.resolveAsset('./assets/mark_use.png')"
         :style="{ left: `${useMarker.left}px`, top: `${useMarker.top}px` }" alt="Item currently being used">
    <span v-if="tooltip.value" ref="tooltipElement" class="inventory__tooltip"
          :class="{ 'inventory__tooltip--visible': tooltip.visible }" role="tooltip"
          :style="{ left: `${tooltip.left}px`, top: `${tooltip.top}px` }">
      <span>{{ tooltip.value.name }}</span>
      <span v-if="tooltip.value.description">{{ tooltip.value.description }}</span>
    </span>
    <span v-if="dragPreview.visual" class="drag-preview"
          :style="{ left: `${dragPreview.left}px`, top: `${dragPreview.top}px` }">
      <SeleneVisual :selene="selene" :identifier="dragPreview.visual" :seed="dragPreview.seed" without-offset />
    </span>
    <ContextMenu class="inventory-menu" :open="Boolean(menu.slot)" variant="long"
                 :frame-src="selene.resolveAsset('./assets/menu_long.png')" label="Item actions"
                 :style="{ left: `${menu.left}px`, top: `${menu.top}px` }" @close="menu.slot = undefined">
      <li><button type="button" :disabled="!menu.slot || !items[key(menu.slot)]?.container" @click="sendSlotAction('illarion:open_container_slot')">Open</button></li>
      <li><button type="button" @click="menu.slot && lookAt(menu.slot); menu.slot = undefined">Look at</button></li>
      <li><button type="button" @click="sendSlotAction('illarion:use_slot')">Use</button></li>
      <li><button type="button" @click="useWith">Use with</button></li>
      <li><button type="button" @click="sendSlotAction('illarion:drop_slot_in_front')">Drop</button></li>
    </ContextMenu>
  </section>
</template>

<style scoped>
.inventory { position: absolute; bottom: 0; left: 846px; width: 178px; height: 100%; }
.slot { position: absolute; width: 78px; height: 39px; margin: 0; padding: 0; overflow: hidden; border: 0; clip-path: polygon(50% 0, 100% 50%, 50% 100%, 0 50%); background: v-bind('`url("${selene.resolveAsset("./assets/inv_slot-0.png")}")`') no-repeat; cursor: grab; pointer-events: none; }
.slot:has(.slot__hit:hover) { background-image: v-bind(slotHoverBackground); }
.slot:active { cursor: grabbing; }
.slot:focus-visible { outline: 1px solid #b7d9ba; outline-offset: -2px; }
.slot__hit { position: absolute; z-index: 2; display: block; pointer-events: auto; }
.slot__item { position: absolute; inset: 0; display: block; user-select: none; pointer-events: none; }
.slot__count { position: absolute; z-index: 3; right: 17px; bottom: 7px; color: white; font: bold 12px Arial, sans-serif; line-height: 1; text-shadow: -1px -1px #000, 1px -1px #000, -1px 1px #000, 1px 1px #000; pointer-events: none; }
.inventory__using { position: absolute; z-index: 4; width: 139px; height: 71px; transform: translate(-50%, -50%); pointer-events: none; }
.inventory__tooltip { position: absolute; z-index: 30; display: block; width: max-content; max-width: 280px; padding: 5px 10px; border: 0; border-radius: 9px; background: rgb(0 0 0 / 50%); color: #fff; font: 14px Arial, Helvetica, sans-serif; line-height: normal; text-align: center; white-space: pre-line; opacity: 0; transform: translate(-50%, -50%); transition: opacity 400ms linear; pointer-events: none; }
.inventory__tooltip--visible { opacity: 1; }
.inventory__tooltip span { display: block; }
.inventory-menu { position: absolute; }
.drag-preview { position: absolute; z-index: 10; display: block; width: 0; height: 0; opacity: .85; user-select: none; pointer-events: none; }
.equipment-0 { left: 17px; bottom: 349px; }
.equipment-1 { left: 101px; bottom: 395px; }
.equipment-2 { left: 101px; bottom: 349px; }
.equipment-3 { left: 59px; bottom: 326px; }
.equipment-4 { left: 59px; bottom: 234px; }
.equipment-5 { left: 101px; bottom: 257px; }
.equipment-6 { left: 17px; bottom: 257px; }
.equipment-7 { left: 101px; bottom: 211px; }
.equipment-8 { left: 17px; bottom: 211px; }
.equipment-9 { left: 59px; bottom: 142px; }
.equipment-10 { left: 17px; bottom: 119px; }
.equipment-11 { left: 17px; bottom: 303px; }
.belt-12 { left: 59px; bottom: 78px; }
.belt-13 { left: 17px; bottom: 55px; }
.belt-14 { left: 101px; bottom: 55px; }
.belt-15 { left: 59px; bottom: 32px; }
.belt-16 { left: 17px; bottom: 9px; }
.belt-17 { left: 101px; bottom: 9px; }
</style>

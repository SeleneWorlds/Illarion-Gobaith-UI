<script setup lang="ts">
import { onMounted, onUnmounted, reactive, ref } from 'vue';
import type { ClientNetworkPayload, Coordinate, SelenePointerEvent, SeleneUiApi } from '../selene';
import SeleneVisual from './SeleneVisual.vue';

type ViewId = 'equipment' | 'belt';
interface Slot { viewId: ViewId; slotId: number }
interface HitBand { top: number; left: number; width: number; height: number }
const props = defineProps<{ selene: SeleneUiApi }>();
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
const itemVisuals = reactive<Record<string, string>>({});
const inventoryElement = ref<HTMLElement>();
const slotElements = ref<HTMLElement[]>([]);
const slotHoverBackground = ref('none');
const dragPreview = reactive({ visual: '', seed: '', left: 0, top: 0 });
let clientManifest: Promise<Record<string, string>> | undefined;
let draggedSlot: Slot | undefined;
let draggedCoordinate: Coordinate | undefined;
let useSlot: Slot | undefined;
let unsubscribe: () => void = () => undefined;
const inputUnsubscribers: Array<() => void> = [];

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
  const visual = item && typeof item === 'object' && typeof (item as ClientNetworkPayload).visual === 'string'
    ? (item as ClientNetworkPayload).visual as string
    : undefined;
  if (!visual) {
    delete itemVisuals[slotKey];
    return;
  }
  itemVisuals[slotKey] = visual;
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
  if (event.button !== 0) return;
  draggedSlot = slot;
  useSlot = event.shiftKey ? slot : undefined;
  dragPreview.visual = itemVisuals[key(slot)] ?? '';
  dragPreview.seed = key(slot);
  moveDragPreview(event);
  event.preventDefault();
};
const moveDragPreview = (event: MouseEvent) => {
  if (!draggedSlot || !dragPreview.visual || !inventoryElement.value) return;
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
    });
  } else if (draggedSlot && !target && isInWorldViewport(clientX, clientY)) {
    props.selene.network.sendToServer('illarion:move_slot_to_coordinate', {
      fromViewId: draggedSlot.viewId,
      fromSlotId: draggedSlot.slotId,
      x: coordinate.x,
      y: coordinate.y,
      z: coordinate.z,
    });
  } else if (draggedCoordinate && target) {
    props.selene.network.sendToServer('illarion:move_coordinate_to_slot', {
      fromX: draggedCoordinate.x,
      fromY: draggedCoordinate.y,
      fromZ: draggedCoordinate.z,
      toViewId: target.viewId,
      toSlotId: target.slotId,
    });
  }
  draggedSlot = undefined;
  draggedCoordinate = undefined;
  dragPreview.visual = '';
};
const startWorldDrag = ({ button, shiftKey, clientX, clientY, coordinate }: SelenePointerEvent) => {
  if (button !== 0 || shiftKey || !isInWorldViewport(clientX, clientY)) return;
  draggedCoordinate = coordinate;
};
const finishUse = (event: KeyboardEvent) => {
  if (event.key !== 'Shift' || !useSlot) return;
  props.selene.network.sendToServer('illarion:use_slot', {
    viewId: useSlot.viewId,
    slotId: useSlot.slotId,
  });
  useSlot = undefined;
};

onMounted(() => {
  unsubscribe = props.selene.network.onPayload('illarion:update_slot', updateSlot);
  void resolveClientAsset('client/textures/illarion/ui/inv_slot-7.png')
    .then(url => { slotHoverBackground.value = `url("${url}")`; })
    .catch(error => console.warn('[Illarion inventory]', error));
  window.addEventListener('mousemove', moveDragPreview, true);
  inputUnsubscribers.push(props.selene.input.onPointerDown(startWorldDrag));
  inputUnsubscribers.push(props.selene.input.onPointerUp(endGameDrag));
  window.addEventListener('keyup', finishUse, true);
});
onUnmounted(() => {
  unsubscribe();
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
            :aria-label="`${slot.viewId} slot ${slot.slotId}`" @mousedown="startDrag(slot, $event)">
      <span v-for="band in hitBands" :key="band.top" class="slot__hit" data-selene-interactive
            :style="{ top: `${band.top}px`, left: `${band.left}px`, width: `${band.width}px`, height: `${band.height}px` }" />
      <SeleneVisual v-if="itemVisuals[key(slot)]" class="slot__item" :selene="selene"
                    :identifier="itemVisuals[key(slot)]" :seed="key(slot)" without-offset />
    </button>
    <span v-if="dragPreview.visual" class="drag-preview"
          :style="{ left: `${dragPreview.left}px`, top: `${dragPreview.top}px` }">
      <SeleneVisual :selene="selene" :identifier="dragPreview.visual" :seed="dragPreview.seed" without-offset />
    </span>
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

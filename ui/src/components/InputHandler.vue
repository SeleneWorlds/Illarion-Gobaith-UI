<script setup lang="ts">
import { nextTick, onMounted, onUnmounted, provide, reactive, ref, useTemplateRef, watchEffect } from 'vue';
import { useUiAssetSrc } from '../composables/useClientAsset';
import { type InventoryDragStartDetail, type InventoryItem, type InventorySlotDefinition } from '../inventory';
import type { Coordinate, SelenePointerEvent, WorldEntity } from '../selene';
import { useSelene } from '../selene';
import { inventoryDragKey, type InventoryDropTarget } from '../inventoryDrag';
import { useMenu, useTooltip } from '../overlays';
import { useInventoryStore } from '../stores/inventory';
import { useMagicStore } from '../stores/magic';
import { useAdminRequestStore } from '../stores/adminRequest';
import SeleneVisual from './SeleneVisual.vue';
import WorldContextMenu, { type WorldContextAction } from './WorldContextMenu.vue';

interface InventoryPointer {
  slot: InventorySlotDefinition;
  item: InventoryItem;
  downX: number;
  downY: number;
  dragged: boolean;
}

interface WorldPointer {
  coordinate: Coordinate;
  entity: Promise<WorldEntity | undefined>;
  downX: number;
  downY: number;
  dragged: boolean;
}

interface PendingWorldLookAt {
  coordinate: Coordinate;
  entityId?: number | null;
}

const selene = useSelene();
const inventory = useInventoryStore();
const magic = useMagicStore();
const tooltip = useTooltip();
const menu = useMenu();
const adminRequest = useAdminRequestStore();
const magicCursor = useUiAssetSrc('cursor_magic.png');
const combatCursor = useUiAssetSrc('cursor_combat.png');
const combatCursorActive = ref(false);
const originalCursor = document.documentElement.style.cursor;
const previewElement = useTemplateRef<HTMLElement>('previewElement');
const worldTooltipAnchor = useTemplateRef<HTMLElement>('worldTooltipAnchor');
const preview = reactive({
  visual: undefined as string | undefined,
  seed: undefined as string | undefined,
  count: undefined as number | undefined,
  left: 0,
  top: 0,
});
const worldTooltipPosition = reactive({ left: 0, top: 0 });
let inventoryPointer: InventoryPointer | undefined;
let worldPointer: WorldPointer | undefined;
let pendingUseCoordinate: Coordinate | undefined;
let pendingWorldLookAt: PendingWorldLookAt | undefined;
let pendingEntityTooltip: { networkId: number; tooltip: unknown } | undefined;
let suppressedClick: { x: number; y: number; button: number } | undefined;
let contextRequestId = 0;
const pendingContextRequests = new Map<
  number,
  { clientX: number; clientY: number; coordinate: Coordinate; entityId?: number }
>();
const inputUnsubscribers: Array<() => void> = [];
const networkUnsubscribers: Array<() => void> = [];

watchEffect(() => {
  if (magic.active.value && magicCursor.value) {
    document.documentElement.style.cursor = `url("${magicCursor.value}"), auto`;
  } else if (combatCursorActive.value && combatCursor.value) {
    document.documentElement.style.cursor = `url("${combatCursor.value}"), auto`;
  } else {
    document.documentElement.style.cursor = originalCursor;
  }
});

const updateCombatCursor = (event: KeyboardEvent) => {
  if (event.key === 'Control') {
    combatCursorActive.value = event.type === 'keydown';
  }
};
const resetCombatCursor = () => {
  combatCursorActive.value = false;
};

const isInWorldViewport = (clientX: number, clientY: number) => {
  const container = worldTooltipAnchor.value?.offsetParent;
  if (!(container instanceof HTMLElement)) {
    return false;
  }
  const rect = container.getBoundingClientRect();
  const x = ((clientX - rect.left) * container.offsetWidth) / rect.width;
  const y = ((clientY - rect.top) * container.offsetHeight) / rect.height;
  return x >= 0 && x < 839 && y >= 0 && y < 419;
};

const isNextToControlledCharacter = (coordinate: Coordinate) => {
  const controlled = selene.world.getControlledEntity()?.coordinate;
  if (!controlled || controlled.z !== coordinate.z) {
    return false;
  }
  const dx = controlled.x - coordinate.x;
  const dy = controlled.y - coordinate.y;
  return Math.floor(Math.hypot(dx, dy)) <= 1;
};

const getWorldItemCount = (entity: WorldEntity) => {
  const component = entity.getComponent('illarion:item_count');
  if (!component || typeof component !== 'object') {
    return undefined;
  }
  const overrides = (component as Record<string, unknown>).overrides;
  if (!overrides || typeof overrides !== 'object') {
    return undefined;
  }
  const text = (overrides as Record<string, unknown>).text;
  if (text === '') {
    return 1;
  }
  if (typeof text !== 'string' || !/^\d+$/.test(text)) {
    return undefined;
  }
  const count = Number.parseInt(text, 10);
  return count > 0 ? count : undefined;
};

const updatePreviewPosition = (clientX: number, clientY: number) => {
  const container = previewElement.value?.offsetParent;
  if (!(container instanceof HTMLElement)) {
    return;
  }
  const rect = container.getBoundingClientRect();
  const scale = rect.width / container.offsetWidth;
  preview.left = (clientX - rect.left) / scale;
  preview.top = (clientY - rect.top) / scale;
};

const updateWorldTooltipPosition = (clientX: number, clientY: number) => {
  const container = worldTooltipAnchor.value?.offsetParent;
  if (!(container instanceof HTMLElement)) {
    return;
  }
  const rect = container.getBoundingClientRect();
  const scale = rect.width / container.offsetWidth;
  worldTooltipPosition.left = (clientX - rect.left) / scale;
  worldTooltipPosition.top = (clientY - rect.top) / scale;
};

const anchorWorldTooltipToEntity = (networkId: number) => {
  const anchor = selene.world.projectEntity(networkId);
  if (!anchor) {
    return false;
  }
  worldTooltipPosition.left = anchor.x;
  worldTooltipPosition.top = anchor.y;
  return true;
};

const showWorldTooltip = (value: unknown) => {
  const anchor = worldTooltipAnchor.value;
  if (!anchor || !value || typeof value !== 'object') {
    return;
  }
  const payload = value as Record<string, unknown>;
  const title = typeof payload.name === 'string' ? payload.name : '';
  const description = typeof payload.description === 'string' ? payload.description : undefined;
  if (!title && !description) {
    return;
  }
  void tooltip.show({ anchor, title, description });
};

const resolvePendingEntityTooltip = () => {
  if (
    pendingWorldLookAt?.entityId !== undefined &&
    pendingWorldLookAt.entityId !== null &&
    pendingEntityTooltip?.networkId === pendingWorldLookAt.entityId
  ) {
    showWorldTooltip(pendingEntityTooltip.tooltip);
    pendingEntityTooltip = undefined;
  }
};

const startInventoryDrag = ({ viewId, slotId, clientX, clientY }: InventoryDragStartDetail) => {
  suppressedClick = undefined;
  const slot = { viewId, slotId };
  const item = inventory.getItem(slot.viewId, slot.slotId);
  if (!item) {
    return;
  }
  inventoryPointer = { slot, item, downX: clientX, downY: clientY, dragged: false };
};

const finishUse = (event: KeyboardEvent) => {
  if (event.key === 'Shift') {
    if (pendingUseCoordinate) {
      if (inventory.selectedUseSlots.value.length > 0) {
        inventory.finishUse(pendingUseCoordinate);
      } else {
        selene.network.sendToServer('illarion:use_at', {
          ...pendingUseCoordinate,
          count: inventory.counter.value,
        });
      }
      pendingUseCoordinate = undefined;
    }
    if (inventory.selectedUseSlots.value.length > 0) {
      inventory.finishUse();
    }
  }
};

const onMouseMove = (event: MouseEvent) => {
  if (!inventoryPointer && !worldPointer) {
    return;
  }
  if (inventoryPointer) {
    const wasDragged = inventoryPointer.dragged;
    inventoryPointer.dragged ||=
      Math.abs(event.clientX - inventoryPointer.downX) + Math.abs(event.clientY - inventoryPointer.downY) > 3;
    if (!wasDragged && inventoryPointer.dragged) {
      preview.visual = inventoryPointer.item.visual;
      preview.seed = `${inventoryPointer.slot.viewId}:${inventoryPointer.slot.slotId}`;
      preview.count = Math.min(inventory.counter.value, inventoryPointer.item.count);
      void nextTick(() => updatePreviewPosition(event.clientX, event.clientY));
    }
  }
  if (worldPointer) {
    worldPointer.dragged ||=
      Math.abs(event.clientX - worldPointer.downX) + Math.abs(event.clientY - worldPointer.downY) > 3;
    if (worldPointer.dragged) {
      pendingWorldLookAt = undefined;
      pendingEntityTooltip = undefined;
      tooltip.hide();
    }
  }
  updatePreviewPosition(event.clientX, event.clientY);
};

const onClick = (event: MouseEvent) => {
  const suppressed = suppressedClick;
  suppressedClick = undefined;
  if (
    suppressed &&
    event.button === suppressed.button &&
    event.clientX === suppressed.x &&
    event.clientY === suppressed.y
  ) {
    event.preventDefault();
    event.stopImmediatePropagation();
  }
};

const onPointerDown = ({ button, shiftKey, clientX, clientY, coordinate }: SelenePointerEvent) => {
  if (magic.active.value) {
    if (button === 0 && isInWorldViewport(clientX, clientY)) {
      void selene.world.getEntitiesAt(coordinate).then((entities) => {
        const target = [...entities]
          .reverse()
          .find((entity) => entity.tags.includes('illarion:character') || entity.tags.includes('illarion:item'));
        if (!magic.active.value) {
          return;
        }
        if (target?.tags.includes('illarion:character')) {
          magic.targetEntity('character', target.networkId);
        } else if (target?.tags.includes('illarion:item')) {
          magic.targetEntity('item', target.networkId);
        } else {
          magic.targetField(coordinate);
        }
      });
    }
    return;
  }
  if (button === 0 && shiftKey && isInWorldViewport(clientX, clientY)) {
    pendingUseCoordinate = coordinate;
    return;
  }
  if (button === 0 && !shiftKey && isInWorldViewport(clientX, clientY)) {
    tooltip.hide();
    pendingEntityTooltip = undefined;
    pendingWorldLookAt = { coordinate };
    updateWorldTooltipPosition(clientX, clientY);
    const entities = selene.world.getEntitiesAt(coordinate);
    const entity = entities.then((result) =>
      [...result]
        .reverse()
        .find((candidate) => candidate.tags.includes('illarion:character') || candidate.tags.includes('illarion:item')),
    );
    worldPointer = { coordinate, entity, downX: clientX, downY: clientY, dragged: false };
    const source = worldPointer;
    void Promise.all([entity, entities])
      .then(([draggedEntity, result]) => {
        const entities = result;
        const reversedEntities = [...entities].reverse();
        const lookAtEntity = reversedEntities.find((entity) => entity.tags.includes('illarion:supports_look_at'));
        if (pendingWorldLookAt && pendingWorldLookAt.coordinate === coordinate) {
          pendingWorldLookAt.entityId = lookAtEntity?.networkId ?? null;
          resolvePendingEntityTooltip();
        }
        if (worldPointer !== source) {
          return;
        }
        if (!draggedEntity?.visual || !draggedEntity.draggable || !isNextToControlledCharacter(coordinate)) {
          return;
        }
        preview.visual = draggedEntity.visual;
        preview.seed = String(draggedEntity.networkId);
        const itemCount = draggedEntity.tags.includes('illarion:item') ? getWorldItemCount(draggedEntity) : undefined;
        preview.count = itemCount !== undefined ? Math.min(inventory.counter.value, itemCount) : undefined;
        preview.left = clientX;
        preview.top = clientY;
        void nextTick(() => updatePreviewPosition(clientX, clientY));
      })
      .catch(() => undefined);
  }
};

const requestWorldContextMenu = async (clientX: number, clientY: number, coordinate: Coordinate) => {
  if (!isInWorldViewport(clientX, clientY)) {
    return;
  }
  tooltip.hide();
  const entities = await selene.world.getEntitiesAt(coordinate).catch(() => []);
  const target = [...entities]
    .reverse()
    .find((entity) => entity.tags.includes('illarion:character') || entity.tags.includes('illarion:item'));
  const requestId = ++contextRequestId;
  pendingContextRequests.clear();
  pendingContextRequests.set(requestId, {
    clientX,
    clientY,
    coordinate,
    entityId: target?.networkId,
  });
  selene.network.sendToServer('illarion:request_menu_at', {
    requestId,
    x: coordinate.x,
    y: coordinate.y,
    z: coordinate.z,
    ...(target && { networkId: target.networkId }),
  });
};

const resetPointers = () => {
  inventoryPointer = undefined;
  worldPointer = undefined;
  preview.visual = undefined;
  preview.seed = undefined;
  preview.count = undefined;
};

const releaseOn = (target: InventoryDropTarget) => {
  if (inventoryPointer) {
    const { slot: source, item, dragged } = inventoryPointer;
    if (dragged) {
      suppressedClick = { x: target.clientX, y: target.clientY, button: 0 };
      target.acceptSlot(source, item, inventory.counter.value);
    }
  } else if (worldPointer?.dragged && target.acceptCoordinate) {
    const source = worldPointer;
    const count = inventory.counter.value;
    void source.entity
      .then((entity) => {
        if (entity?.draggable && isNextToControlledCharacter(source.coordinate)) {
          target.acceptCoordinate?.(source.coordinate, count);
        }
      })
      .catch(() => undefined);
  }
  resetPointers();
};

provide(inventoryDragKey, { start: startInventoryDrag, releaseOn });

const onPointerUp = ({ button, clientX, clientY, coordinate }: SelenePointerEvent) => {
  if (magic.active.value) {
    return;
  }
  if (button === 2) {
    resetPointers();
    void requestWorldContextMenu(clientX, clientY, coordinate);
    return;
  }
  if (inventoryPointer) {
    const { slot: source, dragged } = inventoryPointer;
    if (dragged) {
      suppressedClick = { x: clientX, y: clientY, button };
      if (isInWorldViewport(clientX, clientY)) {
        inventory.moveSlotToCoordinate(source.viewId, source.slotId, coordinate, inventory.counter.value);
      }
    }
  } else if (worldPointer?.dragged) {
    const source = worldPointer;
    if (isInWorldViewport(clientX, clientY)) {
      void source.entity
        .then((entity) => {
          if (entity?.tags.includes('illarion:character')) {
            suppressedClick = { x: clientX, y: clientY, button };
            selene.network.sendToServer('illarion:push_character', {
              networkId: entity.networkId,
              x: coordinate.x,
              y: coordinate.y,
              z: coordinate.z,
            });
          } else if (entity?.draggable && isNextToControlledCharacter(source.coordinate)) {
            suppressedClick = { x: clientX, y: clientY, button };
            inventory.moveCoordinateToCoordinate(source.coordinate, coordinate, inventory.counter.value);
          }
        })
        .catch(() => undefined);
    }
  }
  resetPointers();
};

onMounted(() => {
  window.addEventListener('keydown', updateCombatCursor, true);
  window.addEventListener('keyup', updateCombatCursor, true);
  window.addEventListener('blur', resetCombatCursor);
  window.addEventListener('mousemove', onMouseMove, true);
  window.addEventListener('click', onClick, true);
  window.addEventListener('keyup', finishUse, true);
  inputUnsubscribers.push(selene.input.onPointerDown(onPointerDown));
  inputUnsubscribers.push(selene.input.onPointerUp(onPointerUp));
  inputUnsubscribers.push(selene.input.captureKeys('Control'));
  networkUnsubscribers.push(
    selene.network.onPayload('illarion:look_at', (payload) => {
      const pending = pendingWorldLookAt;
      if (
        !pending ||
        payload.x !== pending.coordinate.x ||
        payload.y !== pending.coordinate.y ||
        payload.z !== pending.coordinate.z
      ) {
        return;
      }
      showWorldTooltip(payload.tooltip);
    }),
  );
  networkUnsubscribers.push(
    selene.network.onPayload('illarion:look_at_entity', (payload) => {
      if (typeof payload.networkId !== 'number') {
        return;
      }
      if (!pendingWorldLookAt) {
        if (anchorWorldTooltipToEntity(payload.networkId)) {
          showWorldTooltip(payload.tooltip);
        }
        return;
      }
      pendingEntityTooltip = { networkId: payload.networkId, tooltip: payload.tooltip };
      resolvePendingEntityTooltip();
    }),
  );
  networkUnsubscribers.push(
    selene.network.onPayload('illarion:menu_at', (payload) => {
      const requestId = typeof payload.requestId === 'number' ? payload.requestId : -1;
      const pending = pendingContextRequests.get(requestId);
      pendingContextRequests.delete(requestId);
      if (!pending || !Array.isArray(payload.actions)) {
        return;
      }
      const actions = payload.actions.filter((action): action is WorldContextAction =>
        Boolean(
          action &&
          typeof action === 'object' &&
          typeof (action as Record<string, unknown>).id === 'string' &&
          typeof (action as Record<string, unknown>).label === 'string',
        ),
      );
      if (!actions.length) {
        return;
      }
      void menu
        .open<string>(
          WorldContextMenu,
          { actions },
          {
            label: 'World actions',
            position: { x: pending.clientX, y: pending.clientY },
          },
        )
        .then((action) => {
          if (!action) {
            return;
          }
          if (action === 'report') {
            const target = actions.find((item) => item.id === action)?.target;
            if (target && typeof target.name === 'string' && Number.isSafeInteger(target.characterId)) {
              adminRequest.open({ name: target.name, characterId: target.characterId });
            }
            return;
          }
          const detail = action === 'giveName' ? window.prompt('Name this character:') : undefined;
          const normalizedDetail = detail?.trim();
          if (action === 'giveName' && !normalizedDetail) {
            return;
          }
          if (action === 'lookAt' || action === 'lookAtClose') {
            tooltip.hide();
            pendingEntityTooltip = undefined;
            pendingWorldLookAt = {
              coordinate: pending.coordinate,
              entityId: pending.entityId ?? null,
            };
            updateWorldTooltipPosition(pending.clientX, pending.clientY);
          }
          selene.network.sendToServer('illarion:menu_action_at', {
            action,
            x: pending.coordinate.x,
            y: pending.coordinate.y,
            z: pending.coordinate.z,
            ...(pending.entityId !== undefined && { networkId: pending.entityId }),
            ...(normalizedDetail !== undefined && { detail: normalizedDetail }),
          });
        });
    }),
  );
  networkUnsubscribers.push(
    selene.network.onPayload('illarion:perform_menu_action', (payload) => {
      if (payload.action === 'lookAt') {
        if (typeof payload.networkId === 'number') {
          selene.network.sendToServer('illarion:look_at_entity', {
            networkId: payload.networkId,
            mode: typeof payload.mode === 'number' ? payload.mode : 0,
          });
        } else {
          selene.network.sendToServer('illarion:look_at', { x: payload.x, y: payload.y, z: payload.z });
        }
      } else if (payload.action === 'open') {
        selene.network.sendToServer('illarion:open_container_at', { x: payload.x, y: payload.y, z: payload.z });
      } else if (payload.action === 'use') {
        selene.network.sendToServer('illarion:use_at', {
          x: payload.x,
          y: payload.y,
          z: payload.z,
          count: inventory.counter.value,
        });
      } else if (payload.action === 'useWith') {
        const coordinate =
          typeof payload.x === 'number' && typeof payload.y === 'number' && typeof payload.z === 'number'
            ? { x: payload.x, y: payload.y, z: payload.z }
            : undefined;
        if (!coordinate) {
          return;
        }
        if (inventory.selectedUseSlots.value.length > 0) {
          inventory.finishUse(coordinate);
        } else {
          selene.network.sendToServer('illarion:use_at', {
            ...coordinate,
            count: inventory.counter.value,
          });
        }
      }
    }),
  );
});
onUnmounted(() => {
  document.documentElement.style.cursor = originalCursor;
  window.removeEventListener('keydown', updateCombatCursor, true);
  window.removeEventListener('keyup', updateCombatCursor, true);
  window.removeEventListener('blur', resetCombatCursor);
  window.removeEventListener('mousemove', onMouseMove, true);
  window.removeEventListener('click', onClick, true);
  window.removeEventListener('keyup', finishUse, true);
  inputUnsubscribers.splice(0).forEach((unsubscribe) => unsubscribe());
  networkUnsubscribers.splice(0).forEach((unsubscribe) => unsubscribe());
});
</script>

<template>
  <slot />
  <span
    ref="worldTooltipAnchor"
    class="world-tooltip-anchor"
    :style="{ left: `${worldTooltipPosition.left}px`, top: `${worldTooltipPosition.top}px` }"
  />
  <span
    v-if="preview.visual && preview.seed"
    ref="previewElement"
    class="drag-preview-overlay"
    :style="{ left: `${preview.left}px`, top: `${preview.top}px` }"
  >
    <SeleneVisual :identifier="preview.visual" :seed="preview.seed" without-offset />
    <span v-if="preview.count !== undefined && preview.count > 1" class="drag-preview-count">{{ preview.count }}</span>
  </span>
</template>

<style scoped>
.world-tooltip-anchor {
  position: absolute;
  width: 1px;
  height: 1px;
  pointer-events: none;
}
.drag-preview-overlay {
  position: absolute;
  z-index: 10;
  display: block;
  width: 78px;
  height: 39px;
  transform: translate(-50%, -50%);
  opacity: 0.85;
  user-select: none;
  pointer-events: none;
}
.drag-preview-count {
  position: absolute;
  z-index: 1;
  right: 17px;
  bottom: 7px;
  color: white;
  font:
    bold 12px Arial,
    sans-serif;
  line-height: 1;
  text-shadow:
    -1px -1px #000,
    1px -1px #000,
    -1px 1px #000,
    1px 1px #000;
}
</style>

export type {
  ShowcaseViewId,
  InventoryViewId,
  InventorySlotDefinition,
  InventoryItem,
  InventoryTooltip,
  InventoryTooltipResponse,
} from 'illarion-client-core';
import type { InventorySlotDefinition } from 'illarion-client-core';

export interface InventoryDragStartDetail extends InventorySlotDefinition {
  clientX: number;
  clientY: number;
}

export const sameInventorySlot = (left: InventorySlotDefinition, right: InventorySlotDefinition) =>
  left.viewId === right.viewId && left.slotId === right.slotId;

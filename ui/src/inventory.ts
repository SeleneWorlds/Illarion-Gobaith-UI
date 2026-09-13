export type InventoryViewId = 'equipment' | 'belt';

export interface InventorySlotDefinition {
  viewId: InventoryViewId;
  slotId: number;
}

export interface InventoryDragStartDetail extends InventorySlotDefinition {
  clientX: number;
  clientY: number;
}

export const sameInventorySlot = (left: InventorySlotDefinition, right: InventorySlotDefinition) =>
  left.viewId === right.viewId && left.slotId === right.slotId;

export interface InventoryItem {
  visual: string;
  count: number;
  container: boolean;
}

export interface InventoryTooltip {
  name?: string;
  description?: string;
}

export interface InventoryTooltipResponse {
  slot: InventorySlotDefinition;
  tooltip?: InventoryTooltip;
}

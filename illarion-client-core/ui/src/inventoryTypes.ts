export type ShowcaseViewId = `showcase:${number}`;
export type InventoryViewId = 'equipment' | 'belt' | ShowcaseViewId;

export interface InventorySlotDefinition {
  viewId: InventoryViewId;
  slotId: number;
}

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

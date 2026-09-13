import type { InventorySlotDefinition } from './inventory';

export const isInWorldViewport = (x: number, y: number) => x >= 0 && x < 839 && y >= 0 && y < 419;

export const sameInventorySlot = (left: InventorySlotDefinition, right: InventorySlotDefinition) =>
  left.viewId === right.viewId && left.slotId === right.slotId;

export const inventorySlotAt = (x: number, y: number): InventorySlotDefinition | undefined => {
  const candidate = document
    .elementsFromPoint(x, y)
    .map((node) => (node instanceof HTMLElement ? node.closest<HTMLElement>('[data-inventory-slot-button]') : null))
    .find((node) => node !== null);
  if (!(candidate instanceof HTMLElement)) {
    return undefined;
  }

  const rect = candidate.getBoundingClientRect();
  const normalizedX = Math.abs(x - (rect.left + rect.width / 2)) / (rect.width / 2);
  const normalizedY = Math.abs(y - (rect.top + rect.height / 2)) / (rect.height / 2);
  if (normalizedX + normalizedY > 1) {
    return undefined;
  }

  const viewId = candidate.dataset.viewId;
  const slotId = Number(candidate.dataset.slotId);
  return (viewId === 'equipment' || viewId === 'belt') && Number.isInteger(slotId) ? { viewId, slotId } : undefined;
};

export const inventorySlotElement = (slot: InventorySlotDefinition) =>
  document
    .querySelector<HTMLElement>(
      `[data-inventory-slot-button][data-view-id="${slot.viewId}"][data-slot-id="${slot.slotId}"]`,
    )
    ?.closest<HTMLElement>('[data-inventory-slot]');

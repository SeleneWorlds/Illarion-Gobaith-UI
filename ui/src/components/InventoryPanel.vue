<script setup lang="ts">
import type { InventorySlotDefinition } from '../inventory';
import InventorySlot from './InventorySlot.vue';

const equipmentSlots: InventorySlotDefinition[] = Array.from({ length: 12 }, (_, slotId) => ({
  viewId: 'equipment',
  slotId,
}));
const beltSlots: InventorySlotDefinition[] = Array.from({ length: 6 }, (_, index) => ({
  viewId: 'belt',
  slotId: index + 12,
}));
const slots = [...equipmentSlots, ...beltSlots];
</script>

<template>
  <section class="inventory" aria-label="Equipment and inventory slots">
    <InventorySlot
      v-for="slot in slots"
      :key="`${slot.viewId}:${slot.slotId}`"
      :class="`${slot.viewId}-${slot.slotId}`"
      :view-id="slot.viewId"
      :slot-id="slot.slotId"
    />
  </section>
</template>

<style scoped>
.inventory {
  position: absolute;
  bottom: 0;
  left: 846px;
  width: 178px;
  height: 100%;
}
.equipment-0 {
  left: 17px;
  bottom: 349px;
}
.equipment-1 {
  left: 101px;
  bottom: 395px;
}
.equipment-2 {
  left: 101px;
  bottom: 349px;
}
.equipment-3 {
  left: 59px;
  bottom: 326px;
}
.equipment-4 {
  left: 59px;
  bottom: 234px;
}
.equipment-5 {
  left: 101px;
  bottom: 257px;
}
.equipment-6 {
  left: 17px;
  bottom: 257px;
}
.equipment-7 {
  left: 101px;
  bottom: 211px;
}
.equipment-8 {
  left: 17px;
  bottom: 211px;
}
.equipment-9 {
  left: 59px;
  bottom: 142px;
}
.equipment-10 {
  left: 17px;
  bottom: 119px;
}
.equipment-11 {
  left: 17px;
  bottom: 303px;
}
.belt-12 {
  left: 59px;
  bottom: 78px;
}
.belt-13 {
  left: 17px;
  bottom: 55px;
}
.belt-14 {
  left: 101px;
  bottom: 55px;
}
.belt-15 {
  left: 59px;
  bottom: 32px;
}
.belt-16 {
  left: 17px;
  bottom: 9px;
}
.belt-17 {
  left: 101px;
  bottom: 9px;
}
</style>

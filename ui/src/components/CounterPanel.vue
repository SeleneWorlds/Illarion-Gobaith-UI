<script setup lang="ts">
import type { SeleneUiApi } from '../selene';
import ClockDisplay from './ClockDisplay.vue';
import ItemCounter from './ItemCounter.vue';

defineProps<{ selene: SeleneUiApi }>();
const counter = defineModel<number>({ required: true });
</script>

<template>
  <section class="counter" aria-label="Counter and clock">
    <img :src="selene.resolveAsset('./assets/gui_counter.png')" alt="">
    <ItemCounter
      v-model="counter"
      :menu-frame-src="selene.resolveAsset('./assets/menu_long.png')"
      :editor-frame-src="selene.resolveAsset('./assets/menu_short.png')"
      :confirm-src="selene.resolveAsset('./assets/spellbook_store.png')"
      :cancel-src="selene.resolveAsset('./assets/menu_close.png')"
    />
    <ClockDisplay />
  </section>
</template>

<style scoped>
.counter {
  position: absolute;
  bottom: 0;
  left: 385px;
  width: 71px;
  height: 120px;
  color: #d8e4ff;
  text-align: center;
  text-shadow: 1px 1px 2px #000;
}

.counter > img {
  position: absolute;
  inset: 0;
  display: block;
  width: 71px;
  height: 120px;
  user-select: none;
}
</style>

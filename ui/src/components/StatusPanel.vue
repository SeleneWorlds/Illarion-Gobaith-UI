<script setup lang="ts">
import { computed, onUnmounted, ref } from 'vue';
import type { SeleneUiApi } from '../selene';

const props = defineProps<{ selene: SeleneUiApi }>();
const backgroundImage = (path: string) => ({
  backgroundImage: `url("${props.selene.resolveAsset(path)}")`,
});
const statusBar = (payloadId: string, asset: string) => {
  const value = ref(0);
  const unsubscribe = props.selene.network.onPayload(payloadId, (payload) => {
    if (typeof payload.value === 'number' && Number.isFinite(payload.value)) {
      value.value = Math.min(1, Math.max(0, payload.value));
    }
  });
  onUnmounted(unsubscribe);

  return computed(() => ({
    ...backgroundImage(asset),
    height: `${value.value * 100}%`,
  }));
};
const healthStyle = statusBar('illarion:health', './assets/status_health.png');
const foodStyle = statusBar('illarion:food', './assets/status_food.png');
const manaStyle = statusBar('illarion:mana', './assets/status_mana.png');
</script>

<template>
  <section class="status" aria-label="Character status">
    <img class="status__frame" :src="selene.resolveAsset('./assets/gui_status.png')" alt="">
    <div class="status__bar status__bar--health"><span :style="healthStyle" /></div>
    <div class="status__bar status__bar--food"><span :style="foodStyle" /></div>
    <div class="status__bar status__bar--mana"><span :style="manaStyle" /></div>
  </section>
</template>

<style scoped>
.status { position: absolute; right: -1px; bottom: 454px; width: 177px; height: 139px; }
.status__frame { position: absolute; inset: 0; display: block; width: 177px; height: 139px; user-select: none; }
.status__bar { position: absolute; bottom: 28px; width: 12px; height: 80px; overflow: hidden; background: rgb(7 8 8 / 78%); }
.status__bar span { position: absolute; right: 0; bottom: 0; left: 0; background-position: bottom; background-repeat: repeat-y; transition: height 0.5s linear; }
.status__bar--health { left: 53px; }
.status__bar--food { left: 81px; }
.status__bar--mana { left: 109px; }
</style>

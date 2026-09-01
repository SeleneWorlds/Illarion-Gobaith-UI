<script setup lang="ts">
import { computed, onUnmounted, ref } from 'vue';
import type { SeleneUiApi } from '../selene';

const props = defineProps<{ selene: SeleneUiApi }>();
const health = ref(0);

const unsubscribe = props.selene.network.onPayload('illarion:health', (payload) => {
  if (typeof payload.value === 'number' && Number.isFinite(payload.value)) {
    health.value = Math.min(1, Math.max(0, payload.value));
  }
});
onUnmounted(unsubscribe);

const opacity = computed(() => (
  health.value > 0 && health.value < 0.3
    ? (0.3 - health.value) / 0.4
    : 0
));

const fogMask = `url("${props.selene.resolveAsset('./assets/fog_overlay.png')}")`;
</script>

<template>
  <div
    class="blood-fog"
    :style="{ opacity, maskImage: fogMask, WebkitMaskImage: fogMask }"
    aria-hidden="true"
  />
</template>

<style scoped>
.blood-fog {
  position: absolute;
  top: 0;
  left: 0;
  width: 846px;
  height: 419px;
  background: rgb(238 24 24);
  mask-position: 0 0;
  mask-size: 100% 100%;
  mask-repeat: no-repeat;
  -webkit-mask-position: 0 0;
  -webkit-mask-size: 100% 100%;
  -webkit-mask-repeat: no-repeat;
  pointer-events: none;
  transition: opacity 0.5s linear;
}
</style>

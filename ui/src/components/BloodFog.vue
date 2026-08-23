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
</script>

<template>
  <div class="blood-fog" :style="{ opacity }" aria-hidden="true" />
</template>

<style scoped>
.blood-fog {
  position: absolute;
  top: 0;
  left: 0;
  width: 846px;
  height: 419px;
  background: radial-gradient(
    ellipse 43% 33% at 50% 50%,
    rgb(163 16 16 / 54%) 0%,
    rgb(179 18 18 / 70%) 44%,
    rgb(195 20 20 / 89%) 82%,
    rgb(196 20 20 / 94%) 100%
  );
  pointer-events: none;
  transition: opacity 0.5s linear;
}
</style>

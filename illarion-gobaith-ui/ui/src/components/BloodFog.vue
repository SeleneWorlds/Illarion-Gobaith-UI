<script setup lang="ts">
import { computed } from 'vue';
import { useUiAssetSrc } from '../composables/useClientAsset';
import { useVitalsStore } from '../stores/vitals';

const { health } = useVitalsStore();

const opacity = computed(() => (health.value > 0 && health.value < 0.3 ? (0.3 - health.value) / 0.4 : 0));

const fogMaskUrl = useUiAssetSrc('fog_overlay.png');
const fogMask = computed(() => fogMaskUrl.value ? `url("${fogMaskUrl.value}")` : 'none');
</script>

<template>
  <div class="blood-fog" :style="{ opacity, maskImage: fogMask, WebkitMaskImage: fogMask }" aria-hidden="true" />
</template>

<style scoped>
.blood-fog {
  position: absolute;
  top: 0;
  left: 0;
  width: 846px;
  height: 419px;
  background: rgb(255 26 26);
  mask-position: 0 0;
  mask-size: 100% 100%;
  mask-repeat: no-repeat;
  -webkit-mask-position: 0 0;
  -webkit-mask-size: 100% 100%;
  -webkit-mask-repeat: no-repeat;
  pointer-events: none;
}
</style>

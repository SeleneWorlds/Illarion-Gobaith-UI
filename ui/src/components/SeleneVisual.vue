<script setup lang="ts">
import { computed } from 'vue';
import { useVisual, type RenderLayer } from '../composables/useVisual';

const props = withDefaults(
  defineProps<{
    identifier?: string;
    seed?: string;
    withoutOffset?: boolean;
  }>(),
  { seed: '', withoutOffset: false },
);
const layers = useVisual(
  () => props.identifier,
  () => props.seed,
  () => props.withoutOffset,
);
const layerStyle = computed(() => (layer: RenderLayer) => ({
  transform: `translate(calc(-50% + ${layer.offsetX}px), calc(-50% + ${layer.offsetY}px)) scale(${layer.flipX ? -1 : 1}, ${layer.flipY ? -1 : 1})`,
}));
</script>

<template>
  <span class="selene-visual" aria-hidden="true">
    <img
      v-for="(layer, index) in layers"
      :key="`${index}:${layer.texture}`"
      :src="layer.texture"
      alt=""
      :style="layerStyle(layer)"
    />
  </span>
</template>

<style scoped>
.selene-visual {
  position: absolute;
  inset: 0;
  display: block;
  overflow: visible;
  pointer-events: none;
}
.selene-visual img {
  position: absolute;
  top: 50%;
  left: 50%;
  display: block;
  max-width: none;
  max-height: none;
  user-select: none;
}
</style>

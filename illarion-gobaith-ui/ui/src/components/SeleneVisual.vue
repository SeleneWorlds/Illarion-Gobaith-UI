<script setup lang="ts">
import { useHudLayout } from '../layout';
import { computed } from 'vue';
import { useVisual, type RenderLayer } from '../composables/useVisual';

const props = withDefaults(
  defineProps<{
    identifier?: string;
    animation?: string;
    seed?: string;
    withoutOffset?: boolean;
    gridSized?: boolean;
  }>(),
  { seed: '', withoutOffset: false },
);
const layout = useHudLayout();
const visualScale = computed(() => (props.gridSized ? 1 / layout.scale : 1));
const layers = useVisual(
  () => props.identifier,
  () => props.seed,
  () => props.withoutOffset,
  () => props.animation,
);
const layerStyle = computed(() => (layer: RenderLayer) => ({
  transform: `translate(calc(-50% + ${layer.offsetX * visualScale.value}px), calc(-50% + ${layer.offsetY * visualScale.value}px)) scale(${(layer.flipX ? -1 : 1) * visualScale.value}, ${(layer.flipY ? -1 : 1) * visualScale.value})`,
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

<script setup lang="ts">
// TODO deslop file
import { computed, onUnmounted, ref, watch } from 'vue';
import { resolveClientAsset } from '../clientAssets';
import { useSelene, type VisualDefinition, type VisualFrameDefinition } from '../selene';

interface RenderLayer { texture: string; offsetX: number; offsetY: number; flipX: boolean; flipY: boolean }
const props = withDefaults(defineProps<{
  identifier?: string;
  seed?: string;
  withoutOffset?: boolean;
}>(), { seed: '', withoutOffset: false });
const selene = useSelene();

const layers = ref<RenderLayer[]>([]);
let generation = 0;
let animationFrame = 0;
let animationStarted = 0;
let animationDuration = 0;
let frames: RenderLayer[][] = [];
let frameRequest: number | undefined;

const hash = (value: string) => {
  let result = 0;
  for (let index = 0; index < value.length; index++) result = Math.imul(31, result) + value.charCodeAt(index) | 0;
  return Math.abs(result);
};
const asFrame = (frame: string | VisualFrameDefinition, parent: VisualDefinition): VisualFrameDefinition =>
  typeof frame === 'string' ? { ...parent, texture: frame } : { ...parent, ...frame };
const makeLayer = async (frame: VisualFrameDefinition): Promise<RenderLayer | undefined> => frame.texture ? {
  texture: await resolveClientAsset(selene, frame.texture),
  offsetX: props.withoutOffset ? 0 : frame.offsetX ?? 0,
  offsetY: props.withoutOffset ? 0 : frame.offsetY ?? 0,
  flipX: frame.flipX ?? false,
  flipY: frame.flipY ?? false,
} : undefined;
const definitionFrames = (definition: VisualDefinition): VisualFrameDefinition[] => {
  if (definition.frames?.length) return definition.frames.map(frame => asFrame(frame, definition));
  if (definition.type === 'variants' && definition.textures?.length) {
    return [asFrame(definition.textures[hash(props.seed || props.identifier || '') % definition.textures.length], definition)];
  }
  if (definition.textures?.length) return definition.textures.map(texture => asFrame(texture, definition));
  if (definition.texture) return [definition];
  const animation = Object.values(definition.animations ?? {})[0];
  if (animation?.frames?.length) return animation.frames.map(frame => asFrame(frame, { ...definition, ...animation }));
  return animation?.textures?.map(texture => asFrame(texture, { ...definition, ...animation })) ?? [];
};
const stop = () => {
  if (frameRequest !== undefined) cancelAnimationFrame(frameRequest);
  frameRequest = undefined;
};
const tick = (now: number) => {
  if (frames.length < 2) return;
  const index = Math.floor((now - animationStarted) / (animationDuration * 1000 / frames.length)) % frames.length;
  if (index !== animationFrame) {
    animationFrame = index;
    layers.value = frames[index];
  }
  frameRequest = requestAnimationFrame(tick);
};
const load = async () => {
  const current = ++generation;
  stop();
  layers.value = [];
  if (!props.identifier) return;
  try {
    const definition = await selene.visuals.getDefinition(props.identifier);
    const definitions = definition.layers?.length ? definition.layers : [definition];
    const layerFrames = await Promise.all(definitions.map(async part => {
      const result = await Promise.all(definitionFrames(part).map(makeLayer));
      return result.filter((layer): layer is RenderLayer => Boolean(layer));
    }));
    const count = Math.max(0, ...layerFrames.map(value => value.length));
    frames = Array.from({ length: count }, (_, index) => layerFrames.flatMap(value => value[index % value.length] ?? []));
    if (current !== generation) return;
    animationDuration = definition.duration ?? Object.values(definition.animations ?? {})[0]?.duration ?? 1;
    animationStarted = performance.now();
    animationFrame = 0;
    layers.value = frames[0] ?? [];
    if (frames.length > 1) frameRequest = requestAnimationFrame(tick);
  } catch (error) {
    console.warn('[Selene visual]', props.identifier, error);
  }
};
watch(() => [props.identifier, props.seed, props.withoutOffset], () => void load(), { immediate: true });
onUnmounted(() => { generation++; stop(); });
const layerStyle = computed(() => (layer: RenderLayer) => ({
  transform: `translate(calc(-50% + ${layer.offsetX}px), calc(-50% + ${layer.offsetY}px)) scale(${layer.flipX ? -1 : 1}, ${layer.flipY ? -1 : 1})`,
}));
</script>

<template>
  <span class="selene-visual" aria-hidden="true">
    <img v-for="(layer, index) in layers" :key="`${index}:${layer.texture}`" :src="layer.texture" alt="" :style="layerStyle(layer)">
  </span>
</template>

<style scoped>
.selene-visual { position: absolute; inset: 0; display: block; overflow: visible; pointer-events: none; }
.selene-visual img { position: absolute; top: 50%; left: 50%; display: block; max-width: none; max-height: none; user-select: none; }
</style>

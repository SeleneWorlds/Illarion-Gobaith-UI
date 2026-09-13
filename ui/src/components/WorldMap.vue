<script setup lang="ts">
import { computed, nextTick, onUnmounted, ref, useTemplateRef, watch } from 'vue';
import { MAP_COLORS } from '../map';
import { useSelene } from '../selene';
import { useMinimapStore } from '../stores/minimap';

const selene = useSelene();
const minimap = useMinimapStore();
const canvas = useTemplateRef<HTMLCanvasElement>('canvas');
const visible = ref(false);
const WORLD_SIZE = 1024;
const WORLD_OFFSET_X = 500;
const WORLD_OFFSET_Y = 524;
const crosshairLeft = computed(() => (WORLD_OFFSET_X + minimap.cameraCoordinate.value.x) / 2);
const crosshairTop = computed(() => (WORLD_SIZE - (WORLD_OFFSET_Y - minimap.cameraCoordinate.value.y)) / 2);

const draw = () => {
  const context = canvas.value?.getContext('2d');
  if (!context) {
    return;
  }
  const image = context.createImageData(WORLD_SIZE, WORLD_SIZE);
  for (let offset = 3; offset < image.data.length; offset += 4) {
    image.data[offset] = 255;
  }
  const level = Math.round(minimap.cameraCoordinate.value.z);
  for (const [key, colorIndex] of minimap.tiles) {
    const [x, y, z] = key.split(':').map(Number);
    if (z !== level) {
      continue;
    }
    const worldX = WORLD_OFFSET_X + x;
    const worldY = WORLD_OFFSET_Y - y;
    if (worldX < 0 || worldX >= WORLD_SIZE || worldY < 0 || worldY >= WORLD_SIZE) {
      continue;
    }
    const canvasY = WORLD_SIZE - 1 - worldY;
    const color = MAP_COLORS[colorIndex] ?? MAP_COLORS[0];
    const offset = (canvasY * WORLD_SIZE + worldX) * 4;
    image.data[offset] = color[0];
    image.data[offset + 1] = color[1];
    image.data[offset + 2] = color[2];
  }
  context.putImageData(image, 0, 0);
};

const open = () => {
  if (Math.round(minimap.cameraCoordinate.value.z) === 0) {
    visible.value = true;
  }
};
const close = () => {
  visible.value = false;
};
defineExpose({ open });
const onKeydown = (event: KeyboardEvent) => {
  if (event.key === 'Escape') {
    if (visible.value) {
      close();
    }
    return;
  }
  if (event.key !== 'F9' || event.repeat) {
    return;
  }
  event.preventDefault();
  event.stopPropagation();
  if (visible.value) {
    close();
  } else {
    open();
  }
};
selene.input.captureKeys('F9');
watch(minimap.revision, () => {
  if (visible.value) {
    draw();
  }
});
watch(minimap.cameraCoordinate, (coordinate) => {
  if (visible.value && Math.round(coordinate.z) !== 0) {
    close();
  }
});
window.addEventListener('keydown', onKeydown);
watch(visible, async (value) => {
  if (!value) {
    return;
  }
  await nextTick();
  draw();
});
onUnmounted(() => {
  window.removeEventListener('keydown', onKeydown);
});
</script>

<template>
  <section v-if="visible" class="world-map" aria-label="World map" data-selene-interactive>
    <img class="frame" :src="selene.resolveAsset('./assets/menu_short.png')" alt="" />
    <div class="viewport">
      <canvas ref="canvas" class="surface" :width="WORLD_SIZE" :height="WORLD_SIZE" />
      <span class="crosshair" aria-hidden="true" />
    </div>
    <button class="close" type="button" aria-label="Close world map" @click="close">
      <img :src="selene.resolveAsset('./assets/menu_close.png')" alt="" />
    </button>
  </section>
</template>

<style scoped>
.world-map {
  position: absolute;
  z-index: 15;
  left: 212px;
  bottom: 134px;
  width: 600px;
  height: 500px;
  pointer-events: auto;
}
.frame {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  filter: drop-shadow(0 4px 9px #000);
  pointer-events: none;
}
.viewport {
  position: absolute;
  top: 50px;
  left: 50px;
  width: 500px;
  height: 400px;
  overflow: hidden;
  background: #000;
}
.surface {
  display: block;
  width: 512px;
  height: 512px;
  image-rendering: pixelated;
}
.crosshair,
.crosshair::after {
  position: absolute;
  width: 20px;
  height: 1px;
  background: rgb(0 0 128);
  content: '';
  pointer-events: none;
  transform: translate(-50%, -50%);
}
.crosshair {
  top: calc(v-bind(crosshairTop) * 1px);
  left: calc(v-bind(crosshairLeft) * 1px);
}
.crosshair::after {
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%) rotate(90deg);
}
.close {
  position: absolute;
  left: 400px;
  bottom: 40px;
  width: 40px;
  height: 95px;
  padding: 0;
  border: 0;
  background: transparent;
  cursor: pointer;
}
.close img {
  display: block;
  width: 100%;
  height: 100%;
}
</style>

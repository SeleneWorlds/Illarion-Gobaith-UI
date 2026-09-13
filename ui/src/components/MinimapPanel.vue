<script setup lang="ts">
import { computed, onMounted, useTemplateRef, watch } from 'vue';
import { MAP_COLORS } from '../map';
import { useMenu } from '../overlays';
import { useMinimapStore } from '../stores/minimap';
import MinimapMenu from './MinimapMenu.vue';

const SIZE = 256;
const RADIUS = SIZE / 2;
const emit = defineEmits<{ openWorldMap: [] }>();

const canvas = useTemplateRef<HTMLCanvasElement>('canvas');
const menu = useMenu();
const minimap = useMinimapStore();
const isGroundLevel = computed(() => Math.round(minimap.cameraCoordinate.value.z) === 0);
const zoom = minimap.zoom;
const rotation = computed(() => (minimap.rotated.value ? 1 : 0));

const onClick = (event?: MouseEvent) => {
  if (event?.shiftKey) {
    minimap.toggleRotation();
  } else {
    minimap.toggleZoom();
  }
};
const onScroll = (event: WheelEvent) => {
  const direction = event.deltaY < 0 ? 1 : -1;
  minimap.adjustZoom(direction * 0.1);
};
const onContextMenu = async (event: MouseEvent) => {
  const action = await menu.open<'openWorldMap' | number>(
    MinimapMenu,
    { canOpenWorldMap: isGroundLevel.value, canZoomIn: minimap.canZoomIn.value, canZoomOut: minimap.canZoomOut.value },
    { label: 'Minimap options', anchor: event.currentTarget as HTMLElement },
  );
  if (action === 'openWorldMap') {
    emit('openWorldMap');
  } else if (action !== undefined) {
    minimap.adjustZoom(action);
  }
};

const draw = () => {
  const context = canvas.value?.getContext('2d');
  if (!context) {
    return;
  }
  const camera = minimap.cameraCoordinate.value;
  const center = {
    x: Math.round(camera.x),
    y: Math.round(camera.y),
    z: Math.round(camera.z),
  };
  const image = context.createImageData(SIZE, SIZE);
  for (let y = 0; y < SIZE; y += 1) {
    for (let x = 0; x < SIZE; x += 1) {
      const colorIndex = minimap.getColorIndex(center.x + x - RADIUS, center.y + y - RADIUS, center.z);
      const color = MAP_COLORS[colorIndex] ?? MAP_COLORS[0];
      const offset = (y * SIZE + x) * 4;
      image.data[offset] = color[0];
      image.data[offset + 1] = color[1];
      image.data[offset + 2] = color[2];
      image.data[offset + 3] = 255;
    }
  }
  context.putImageData(image, 0, 0);
};
onMounted(() => {
  draw();
});
watch([minimap.revision, minimap.cameraCoordinate], draw);
</script>

<template>
  <section
    class="minimap"
    aria-label="Minimap"
    data-selene-interactive
    tabindex="0"
    title="Click to toggle zoom; wheel to zoom; Shift-click to rotate; right-click for menu"
    @click="onClick"
    @contextmenu.prevent.stop="onContextMenu"
    @wheel.prevent.stop="onScroll"
  >
    <canvas ref="canvas" class="surface" :width="SIZE" :height="SIZE" />
    <span class="crosshair" aria-hidden="true" />
  </section>
</template>

<style scoped>
.minimap {
  position: absolute;
  top: 0;
  right: 0;
  width: 160px;
  height: 160px;
  overflow: hidden;
  background: #0d1010;
  cursor: pointer;
  pointer-events: auto;
}

.minimap .surface {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 256px;
  height: 256px;
  transform: translate(-50%, -50%) scale(v-bind(zoom)) rotate(calc(v-bind(rotation) * -45deg));
  transform-origin: center;
  transition: transform 100ms linear;
  image-rendering: pixelated;
}

.crosshair,
.crosshair::after {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 20px;
  height: 1px;
  background: rgb(0 0 128);
  content: '';
  pointer-events: none;
  transform: translate(-50%, -50%);
}

.crosshair::after {
  transform: translate(-50%, -50%) rotate(90deg);
}
</style>

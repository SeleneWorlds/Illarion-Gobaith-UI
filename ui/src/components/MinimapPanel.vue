<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue';
import type { MapTile, SeleneUiApi } from '../selene';
import { createPlayerStore } from '../stores/player';

const props = defineProps<{ selene: SeleneUiApi }>();
const SIZE = 160;
const RADIUS = SIZE / 2;
const COLORS = [
  [0, 0, 0],
  [182, 214, 158],
  [155, 120, 90],
  [175, 183, 165],
  [126, 193, 238],
  [255, 255, 0],
  [205, 101, 101],
  [255, 255, 255],
  [140, 160, 100],
] as const;

const canvas = ref<HTMLCanvasElement>();
const player = createPlayerStore(props.selene.storage);
const unsubscribers: Array<() => void> = [];
let mounted = false;
const tileKey = (tile: Pick<MapTile, 'x' | 'y' | 'z'>) => `${tile.x}:${tile.y}:${tile.z}`;

const draw = () => {
  const context = canvas.value?.getContext('2d');
  if (!context) return;
  const camera = props.selene.world.getCameraCoordinate();
  const center = {
    x: Math.round(camera.x),
    y: Math.round(camera.y),
    z: Math.round(camera.z),
  };
  const image = context.createImageData(SIZE, SIZE);
  for (let y = 0; y < SIZE; y += 1) {
    for (let x = 0; x < SIZE; x += 1) {
      const colorIndex = player.minimapTiles.get(
        tileKey({ x: center.x + x - RADIUS, y: center.y + y - RADIUS, z: center.z }),
      ) ?? 0;
      const color = COLORS[colorIndex] ?? COLORS[0];
      const offset = (y * SIZE + x) * 4;
      image.data[offset] = color[0];
      image.data[offset + 1] = color[1];
      image.data[offset + 2] = color[2];
      image.data[offset + 3] = 255;
    }
  }
  context.putImageData(image, 0, 0);
};
const refreshTiles = () => {
  for (const tile of props.selene.world.getMapTiles()) {
    const colorIndex = tile.visualMetadata.mapColorIndex;
    if (typeof colorIndex === 'number') {
      player.setMinimapTile(tile.x, tile.y, tile.z, colorIndex);
    }
  }
  draw();
};

onMounted(async () => {
  mounted = true;
  await player.initialize();
  if (!mounted) return;
  refreshTiles();
  unsubscribers.push(props.selene.world.onMapChanged(refreshTiles));
  unsubscribers.push(props.selene.world.onCameraCoordinateChanged(draw));
});
onUnmounted(() => {
  mounted = false;
  unsubscribers.forEach(unsubscribe => unsubscribe());
  void player.flush().catch((error: unknown) => console.warn('Could not persist player data.', error));
});
</script>

<template>
  <section class="minimap" aria-label="Minimap">
    <canvas ref="canvas" class="minimap__surface" :width="SIZE" :height="SIZE" />
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
}

.minimap__surface {
  position: absolute;
  top: -80px;
  left: -80px;
  width: 320px;
  height: 320px;
  image-rendering: pixelated;
}
</style>

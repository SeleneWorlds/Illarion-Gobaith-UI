<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import type { MapTile, SeleneUiApi } from '../selene';
import { createPlayerStore } from '../stores/player';

const props = defineProps<{ selene: SeleneUiApi }>();
const SIZE = 256;
const RADIUS = SIZE / 2;
const MIN_ZOOM = 1;
const MAX_ZOOM = 2;
const ZOOM_STEP = 0.1;
const ZOOM_STORAGE_KEY = 'zoomMinimap';
const ROTATION_STORAGE_KEY = 'rotateMinimap';
const COLORS = [
  [0, 0, 0],
  [182, 214, 158],
  [155, 120, 90],
  [175, 183, 165],
  [126, 193, 238],
  [255, 255, 204],
  [205, 101, 101],
  [255, 255, 255],
  [140, 160, 100],
] as const;

const canvas = ref<HTMLCanvasElement>();
const zoom = ref(MIN_ZOOM);
const rotated = ref(false);
const player = createPlayerStore(props.selene.storage);
const unsubscribers: Array<() => void> = [];
let mounted = false;
const tileKey = (tile: Pick<MapTile, 'x' | 'y' | 'z'>) => `${tile.x}:${tile.y}:${tile.z}`;
const surfaceStyle = computed(() => ({
  transform: `translate(-50%, -50%) scale(${zoom.value}) rotate(${rotated.value ? -45 : 0}deg)`,
}));

const saveZoom = () => props.selene.storage.save(ZOOM_STORAGE_KEY, String(Math.round((zoom.value - 1) * 1000)));
const saveRotation = () => props.selene.storage.save(ROTATION_STORAGE_KEY, rotated.value ? '1' : '0');
const toggleZoom = (event?: MouseEvent) => {
  if (event?.shiftKey) {
    rotated.value = !rotated.value;
    void saveRotation();
    return;
  }
  zoom.value = zoom.value < MAX_ZOOM ? MAX_ZOOM : MIN_ZOOM;
  void saveZoom();
};
const adjustZoom = (event: WheelEvent) => {
  const direction = event.deltaY < 0 ? 1 : -1;
  zoom.value = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, Math.round((zoom.value + direction * ZOOM_STEP) * 10) / 10));
  void saveZoom();
};

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
  const [storedZoom, storedRotation] = await Promise.all([
    props.selene.storage.load(ZOOM_STORAGE_KEY),
    props.selene.storage.load(ROTATION_STORAGE_KEY),
    player.initialize(),
  ]);
  if (!mounted) return;
  const legacyZoom = Number(storedZoom);
  if (storedZoom !== null && Number.isFinite(legacyZoom)) {
    zoom.value = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, 1 + legacyZoom / 1000));
  }
  rotated.value = storedRotation === '1' || storedRotation === 'true';
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
  <section
    class="minimap"
    aria-label="Minimap"
    data-selene-interactive
    tabindex="0"
    title="Click to toggle zoom; wheel to zoom; Shift-click to rotate"
    @click="toggleZoom"
    @keydown.enter.prevent="toggleZoom()"
    @keydown.space.prevent="toggleZoom()"
    @wheel.prevent.stop="adjustZoom"
  >
    <canvas ref="canvas" class="minimap__surface" :style="surfaceStyle" :width="SIZE" :height="SIZE" />
    <span class="minimap__crosshair" aria-hidden="true" />
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

.minimap__surface {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 256px;
  height: 256px;
  transform-origin: center;
  transition: transform 100ms linear;
  image-rendering: pixelated;
}

.minimap__crosshair,
.minimap__crosshair::after {
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

.minimap__crosshair::after {
  transform: translate(-50%, -50%) rotate(90deg);
}
</style>

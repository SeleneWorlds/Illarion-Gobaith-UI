<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue';
import type { MapTile, SeleneUiApi } from '../selene';
import { createPlayerStore } from '../stores/player';
import ContextMenu from './ContextMenu.vue';

const props = defineProps<{ selene: SeleneUiApi }>();
const SIZE = 256;
const RADIUS = SIZE / 2;
const MIN_ZOOM = 1;
const MAX_ZOOM = 2;
const ZOOM_STEP = 0.1;
const ZOOM_STORAGE_KEY = 'zoomMinimap';
const ROTATION_STORAGE_KEY = 'rotateMinimap';
const WORLD_SIZE = 1024;
const WORLD_OFFSET_X = 500;
const WORLD_OFFSET_Y = 524;
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
const worldCanvas = ref<HTMLCanvasElement>();
const zoom = ref(MIN_ZOOM);
const rotated = ref(false);
const menuOpen = ref(false);
const worldMapOpen = ref(false);
const cameraCoordinate = ref(props.selene.world.getCameraCoordinate());
const isGroundLevel = computed(() => Math.round(cameraCoordinate.value.z) === 0);
const player = createPlayerStore(props.selene.storage);
const unsubscribers: Array<() => void> = [];
let mounted = false;
const tileKey = (tile: Pick<MapTile, 'x' | 'y' | 'z'>) => `${tile.x}:${tile.y}:${tile.z}`;
const surfaceStyle = computed(() => ({
  transform: `translate(-50%, -50%) scale(${zoom.value}) rotate(${rotated.value ? -45 : 0}deg)`,
}));
const worldCrosshairStyle = computed(() => ({
  left: `${(WORLD_OFFSET_X + cameraCoordinate.value.x) / 2}px`,
  top: `${(WORLD_SIZE - (WORLD_OFFSET_Y - cameraCoordinate.value.y)) / 2}px`,
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
const zoomBy = (amount: number) => {
  zoom.value = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, Math.round((zoom.value + amount) * 10) / 10));
  menuOpen.value = false;
  void saveZoom();
};
const showWorldMap = () => {
  if (!isGroundLevel.value) return;
  worldMapOpen.value = true;
  menuOpen.value = false;
  requestAnimationFrame(drawWorldMap);
};
const hideWorldMap = () => {
  worldMapOpen.value = false;
  menuOpen.value = false;
};
const openMenu = () => {
  menuOpen.value = true;
};

function drawWorldMap() {
  const context = worldCanvas.value?.getContext('2d');
  if (!context) return;
  const image = context.createImageData(WORLD_SIZE, WORLD_SIZE);
  for (let offset = 3; offset < image.data.length; offset += 4) image.data[offset] = 255;
  const level = Math.round(cameraCoordinate.value.z);
  for (const [key, colorIndex] of player.minimapTiles) {
    const [x, y, z] = key.split(':').map(Number);
    if (z !== level) continue;
    const worldX = WORLD_OFFSET_X + x;
    const legacyWorldY = WORLD_OFFSET_Y - y;
    if (worldX < 0 || worldX >= WORLD_SIZE || legacyWorldY < 0 || legacyWorldY >= WORLD_SIZE) continue;
    // OpenGL treats the first texture row as the bottom; canvas treats it as the top.
    const canvasY = WORLD_SIZE - 1 - legacyWorldY;
    const color = COLORS[colorIndex] ?? COLORS[0];
    const offset = (canvasY * WORLD_SIZE + worldX) * 4;
    image.data[offset] = color[0];
    image.data[offset + 1] = color[1];
    image.data[offset + 2] = color[2];
  }
  context.putImageData(image, 0, 0);
}

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
  if (worldMapOpen.value) drawWorldMap();
};
const updateCamera = () => {
  cameraCoordinate.value = props.selene.world.getCameraCoordinate();
  draw();
  if (worldMapOpen.value && !isGroundLevel.value) hideWorldMap();
};
const closeMenu = () => { menuOpen.value = false; };
const onWindowKeydown = (event: KeyboardEvent) => {
  if (event.key === 'Escape') {
    if (worldMapOpen.value) hideWorldMap();
    return;
  }
  if (event.key !== 'F9' || event.repeat) return;
  event.preventDefault();
  event.stopPropagation();
  if (worldMapOpen.value) hideWorldMap();
  else showWorldMap();
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
  unsubscribers.push(props.selene.input.captureKeys('F9'));
  unsubscribers.push(props.selene.world.onMapChanged(refreshTiles));
  unsubscribers.push(props.selene.world.onCameraCoordinateChanged(updateCamera));
  window.addEventListener('keydown', onWindowKeydown);
});
onUnmounted(() => {
  mounted = false;
  unsubscribers.forEach(unsubscribe => unsubscribe());
  window.removeEventListener('keydown', onWindowKeydown);
  void player.flush().catch((error: unknown) => console.warn('Could not persist player data.', error));
});
</script>

<template>
  <section
      class="minimap"
      aria-label="Minimap"
      data-selene-interactive
      tabindex="0"
      title="Click to toggle zoom; wheel to zoom; Shift-click to rotate; right-click for menu"
      @click="toggleZoom"
      @contextmenu.prevent.stop="openMenu"
      @keydown.enter.prevent="toggleZoom()"
      @keydown.space.prevent="toggleZoom()"
      @wheel.prevent.stop="adjustZoom"
    >
      <canvas ref="canvas" class="minimap__surface" :style="surfaceStyle" :width="SIZE" :height="SIZE" />
      <span class="minimap__crosshair" aria-hidden="true" />
    </section>

    <ContextMenu class="minimap-menu" :open="menuOpen" :frame-src="selene.resolveAsset('./assets/menu_short.png')" label="Minimap options" @close="closeMenu">
      <li v-if="!worldMapOpen && isGroundLevel">
        <button type="button" @click="showWorldMap">Open world map</button>
      </li>
      <li v-else-if="worldMapOpen">
        <button type="button" @click="hideWorldMap">Close world map</button>
      </li>
      <li><button type="button" :disabled="zoom >= MAX_ZOOM" @click="zoomBy(0.3)">Zoom in</button></li>
      <li><button type="button" :disabled="zoom <= MIN_ZOOM" @click="zoomBy(-0.3)">Zoom out</button></li>
    </ContextMenu>

    <section v-if="worldMapOpen" class="world-map" aria-label="World map" data-selene-interactive>
      <img class="world-map__frame" :src="selene.resolveAsset('./assets/menu_short.png')" alt="">
      <div class="world-map__viewport">
        <canvas ref="worldCanvas" class="world-map__surface" :width="WORLD_SIZE" :height="WORLD_SIZE" />
        <span class="world-map__crosshair minimap__crosshair" :style="worldCrosshairStyle" aria-hidden="true" />
      </div>
      <button class="world-map__close" type="button" aria-label="Close world map" @click="hideWorldMap">
        <img :src="selene.resolveAsset('./assets/menu_close.png')" alt="">
      </button>
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

.minimap-menu {
  top: 154px;
  right: 4px;
}

.world-map {
  position: absolute;
  z-index: 15;
  left: 212px;
  bottom: 134px;
  width: 600px;
  height: 500px;
  pointer-events: auto;
}

.world-map__frame {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  filter: drop-shadow(0 4px 9px #000);
  pointer-events: none;
}

.world-map__viewport {
  position: absolute;
  top: 50px;
  left: 50px;
  width: 500px;
  height: 400px;
  overflow: hidden;
  background: #000;
}

.world-map__surface {
  display: block;
  width: 512px;
  height: 512px;
  image-rendering: pixelated;
}

.world-map__crosshair {
  top: 0;
  left: 0;
}

.world-map__close {
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

.world-map__close img {
  display: block;
  width: 100%;
  height: 100%;
}
</style>

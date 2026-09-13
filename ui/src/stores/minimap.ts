// TODO deslop file
import { computed, inject, readonly, ref, type ComputedRef, type InjectionKey, type Ref } from 'vue';
import type { SeleneUiApi } from '../selene';

const STORAGE_KEY = 'player';
const STORAGE_VERSION = 1;
const SAVE_DELAY_MS = 500;
const ZOOM_STORAGE_KEY = 'zoomMinimap';
const ROTATION_STORAGE_KEY = 'rotateMinimap';
const MIN_ZOOM = 1;
const MAX_ZOOM = 2;

type StoredMinimapTile = [x: number, y: number, z: number, colorIndex: number];

interface StoredPlayerData {
  version: typeof STORAGE_VERSION;
  minimapTiles: StoredMinimapTile[];
}

const tileKey = (x: number, y: number, z: number) => `${x}:${y}:${z}`;

const readTiles = (value: string | null): Map<string, number> => {
  const result = new Map<string, number>();
  try {
    if (!value) {
      return result;
    }
    const data: unknown = JSON.parse(value);
    if (!data || typeof data !== 'object') {
      return result;
    }
    const stored = data as Partial<StoredPlayerData>;
    if (stored.version !== STORAGE_VERSION || !Array.isArray(stored.minimapTiles)) {
      return result;
    }
    for (const tile of stored.minimapTiles) {
      if (!Array.isArray(tile) || tile.length !== 4 || !tile.every(Number.isFinite)) {
        continue;
      }
      const [x, y, z, colorIndex] = tile;
      result.set(tileKey(x, y, z), colorIndex);
    }
  } catch {
    // Corrupt map data can be rebuilt as tiles are observed again.
  }
  return result;
};

export interface MinimapStore {
  readonly tiles: Map<string, number>;
  readonly revision: Readonly<Ref<number>>;
  readonly cameraCoordinate: Readonly<Ref<ReturnType<SeleneUiApi['world']['getCameraCoordinate']>>>;
  readonly zoom: Readonly<Ref<number>>;
  readonly rotated: Readonly<Ref<boolean>>;
  readonly canZoomIn: ComputedRef<boolean>;
  readonly canZoomOut: ComputedRef<boolean>;
  getColorIndex(x: number, y: number, z: number): number;
  initialize(): Promise<void>;
  toggleZoom(): void;
  adjustZoom(amount: number): void;
  toggleRotation(): void;
  dispose(): void;
}

export const minimapStoreKey: InjectionKey<MinimapStore> = Symbol('minimap-store');

export const useMinimapStore = (): MinimapStore => {
  const store = inject(minimapStoreKey);
  if (!store) {
    throw new Error('Minimap store is not provided.');
  }
  return store;
};

export const createMinimapStore = (selene: SeleneUiApi): MinimapStore => {
  const tiles = new Map<string, number>();
  const revision = ref(0);
  const cameraCoordinate = ref(selene.world.getCameraCoordinate());
  const zoom = ref(MIN_ZOOM);
  const rotated = ref(false);
  let saveTimer: ReturnType<typeof setTimeout> | undefined;
  let initialization: Promise<void> | undefined;
  let unsubscribeMap: (() => void) | undefined;
  let unsubscribeCamera: (() => void) | undefined;
  let disposed = false;

  const flush = async () => {
    if (saveTimer !== undefined) {
      clearTimeout(saveTimer);
    }
    saveTimer = undefined;
    const data: StoredPlayerData = { version: STORAGE_VERSION, minimapTiles: [] };
    for (const [key, colorIndex] of tiles) {
      const coordinates = key.split(':').map(Number);
      if (coordinates.length === 3) {
        data.minimapTiles.push([coordinates[0], coordinates[1], coordinates[2], colorIndex]);
      }
    }
    await selene.storage.save(STORAGE_KEY, JSON.stringify(data));
  };

  const scheduleSave = () => {
    if (saveTimer !== undefined) {
      clearTimeout(saveTimer);
    }
    saveTimer = setTimeout(() => {
      void flush().catch((error: unknown) => console.warn('Could not persist minimap data.', error));
    }, SAVE_DELAY_MS);
  };

  const refresh = () => {
    let changed = false;
    for (const tile of selene.world.getMapTiles()) {
      const colorIndex = tile.visualMetadata.mapColorIndex;
      if (typeof colorIndex !== 'number') {
        continue;
      }
      const key = tileKey(tile.x, tile.y, tile.z);
      if (tiles.get(key) === colorIndex) {
        continue;
      }
      tiles.set(key, colorIndex);
      changed = true;
    }
    if (changed) {
      revision.value += 1;
      scheduleSave();
    }
  };

  const saveZoom = () => {
    void selene.storage.save(ZOOM_STORAGE_KEY, String(Math.round((zoom.value - 1) * 1000)));
  };

  const setZoom = (value: number) => {
    zoom.value = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, Math.round(value * 10) / 10));
    saveZoom();
  };

  return {
    tiles,
    revision: readonly(revision),
    cameraCoordinate: readonly(cameraCoordinate),
    zoom: readonly(zoom),
    rotated: readonly(rotated),
    canZoomIn: computed(() => zoom.value < MAX_ZOOM),
    canZoomOut: computed(() => zoom.value > MIN_ZOOM),
    getColorIndex(x, y, z) {
      return tiles.get(tileKey(x, y, z)) ?? 0;
    },
    initialize() {
      initialization ??= (async () => {
        try {
          const [storedTiles, storedZoom, storedRotation] = await Promise.all([
            selene.storage.load(STORAGE_KEY),
            selene.storage.load(ZOOM_STORAGE_KEY),
            selene.storage.load(ROTATION_STORAGE_KEY),
          ]);
          for (const [key, colorIndex] of readTiles(storedTiles)) {
            tiles.set(key, colorIndex);
          }
          const legacyZoom = Number(storedZoom);
          if (storedZoom !== null && Number.isFinite(legacyZoom)) {
            zoom.value = Math.min(MAX_ZOOM, Math.max(MIN_ZOOM, 1 + legacyZoom / 1000));
          }
          rotated.value = storedRotation === '1' || storedRotation === 'true';
        } catch (error) {
          console.warn('Could not load minimap data.', error);
        }
        refresh();
        revision.value += 1;
        if (!disposed) {
          unsubscribeMap = selene.world.onMapChanged(refresh);
          unsubscribeCamera = selene.world.onCameraCoordinateChanged(() => {
            cameraCoordinate.value = selene.world.getCameraCoordinate();
          });
        }
      })();
      return initialization;
    },
    toggleZoom() {
      setZoom(zoom.value < MAX_ZOOM ? MAX_ZOOM : MIN_ZOOM);
    },
    adjustZoom(amount) {
      setZoom(zoom.value + amount);
    },
    toggleRotation() {
      rotated.value = !rotated.value;
      void selene.storage.save(ROTATION_STORAGE_KEY, rotated.value ? '1' : '0');
    },
    dispose() {
      disposed = true;
      unsubscribeMap?.();
      unsubscribeMap = undefined;
      unsubscribeCamera?.();
      unsubscribeCamera = undefined;
      void flush().catch((error: unknown) => console.warn('Could not persist minimap data.', error));
    },
  };
};

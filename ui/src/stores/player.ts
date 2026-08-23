import type { SeleneUiApi } from '../selene';

const STORAGE_KEY = 'player';
const STORAGE_VERSION = 1;
const SAVE_DELAY_MS = 500;

type StoredMinimapTile = [x: number, y: number, z: number, colorIndex: number];
type StorageApi = SeleneUiApi['storage'];

interface StoredPlayerData {
  version: typeof STORAGE_VERSION;
  minimapTiles: StoredMinimapTile[];
}

const minimapTileKey = (x: number, y: number, z: number) => `${x}:${y}:${z}`;

const readMinimapTiles = (value: string | null): Map<string, number> => {
  const result = new Map<string, number>();
  try {
    if (!value) return result;
    const data: unknown = JSON.parse(value);
    if (!data || typeof data !== 'object') return result;
    const stored = data as Partial<StoredPlayerData>;
    if (stored.version !== STORAGE_VERSION || !Array.isArray(stored.minimapTiles)) return result;

    for (const tile of stored.minimapTiles) {
      if (!Array.isArray(tile) || tile.length !== 4 || !tile.every(Number.isFinite)) continue;
      const [x, y, z, colorIndex] = tile;
      result.set(minimapTileKey(x, y, z), colorIndex);
    }
  } catch {
    // Corrupt player data can be rebuilt as map tiles are observed again.
  }
  return result;
};

export interface PlayerStore {
  readonly minimapTiles: Map<string, number>;
  initialize(): Promise<void>;
  setMinimapTile(x: number, y: number, z: number, colorIndex: number): void;
  flush(): Promise<void>;
}

export const createPlayerStore = (storage: StorageApi): PlayerStore => {
  const minimapTiles = new Map<string, number>();
  let saveTimer: ReturnType<typeof setTimeout> | undefined;

  const flush = async () => {
    if (saveTimer !== undefined) clearTimeout(saveTimer);
    saveTimer = undefined;

    const data: StoredPlayerData = { version: STORAGE_VERSION, minimapTiles: [] };
    for (const [key, colorIndex] of minimapTiles) {
      const coordinates = key.split(':').map(Number);
      if (coordinates.length !== 3) continue;
      data.minimapTiles.push([coordinates[0], coordinates[1], coordinates[2], colorIndex]);
    }
    await storage.save(STORAGE_KEY, JSON.stringify(data));
  };

  const scheduleSave = () => {
    if (saveTimer !== undefined) clearTimeout(saveTimer);
    saveTimer = setTimeout(() => {
      void flush().catch((error: unknown) => console.warn('Could not persist player data.', error));
    }, SAVE_DELAY_MS);
  };

  return {
    minimapTiles,
    async initialize() {
      try {
        const storedTiles = readMinimapTiles(await storage.load(STORAGE_KEY));
        for (const [key, colorIndex] of storedTiles) minimapTiles.set(key, colorIndex);
      } catch (error) {
        console.warn('Could not load player data.', error);
      }
    },
    setMinimapTile(x, y, z, colorIndex) {
      const key = minimapTileKey(x, y, z);
      if (minimapTiles.get(key) === colorIndex) return;
      minimapTiles.set(key, colorIndex);
      scheduleSave();
    },
    flush,
  };
};

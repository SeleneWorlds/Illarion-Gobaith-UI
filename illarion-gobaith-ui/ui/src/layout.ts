import { inject, type InjectionKey } from 'vue';

export interface HudLayout {
  scale: number;
  width: number;
  height: number;
  viewportWidth: number;
  viewportHeight: number;
  toHud(point: { x: number; y: number }): { x: number; y: number };
}

export function createHudLayout(tileWidth = 76, tileHeight = 37): HudLayout {
  const scale = Math.max(tileWidth / 76, tileHeight / 37);
  if (!Number.isFinite(scale) || scale <= 0) {
    throw new Error('Invalid render grid tile dimensions.');
  }
  return {
    scale,
    width: Math.round(1024 * scale),
    height: Math.round(768 * scale),
    viewportWidth: Math.round(839 * scale),
    viewportHeight: Math.round(419 * scale),
    toHud: ({ x, y }) => ({ x: x / scale, y: y / scale }),
  };
}

export const hudLayoutKey: InjectionKey<HudLayout> = Symbol('hudLayout');
export const useHudLayout = () => inject(hudLayoutKey, createHudLayout());

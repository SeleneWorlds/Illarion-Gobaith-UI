import type { SeleneUiApi } from './selene';

const assets = new Map<string, Promise<string>>();

export const resolveClientAsset = (selene: SeleneUiApi, path: string): Promise<string> => {
  let asset = assets.get(path);
  if (!asset) {
    asset = selene.resolveAsset(path);
    assets.set(path, asset);
  }
  return asset;
};

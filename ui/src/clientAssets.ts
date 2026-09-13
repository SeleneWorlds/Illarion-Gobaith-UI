import type { SeleneUiApi } from './selene';

interface ClientAssetManifest {
  assets?: Record<string, string>;
}

const manifests = new Map<string, Promise<Record<string, string>>>();
const assets = new Map<string, Promise<string>>();

const loadManifest = (manifestUrl: string) => {
  let manifest = manifests.get(manifestUrl);
  if (!manifest) {
    manifest = fetch(manifestUrl)
      .then((response) => {
        if (!response.ok) {
          throw new Error(`Could not load client asset manifest: ${response.status}`);
        }
        return response.json() as Promise<ClientAssetManifest>;
      })
      .then((value) => value.assets ?? {});
    manifests.set(manifestUrl, manifest);
  }
  return manifest;
};

export const resolveClientAsset = (selene: SeleneUiApi, path: string): Promise<string> => {
  const base = new URL(selene.resolveAsset('./'));
  const manifestUrl = new URL('/client/asset-manifest.json', base).href;
  const key = `${manifestUrl}\n${path}`;
  let asset = assets.get(key);
  if (!asset) {
    asset = loadManifest(manifestUrl).then((manifest) => {
      const publicPath = manifest[path];
      if (!publicPath) {
        throw new Error(`Client asset is missing: ${path}`);
      }
      return new URL(publicPath, base).href;
    });
    assets.set(key, asset);
  }
  return asset;
};

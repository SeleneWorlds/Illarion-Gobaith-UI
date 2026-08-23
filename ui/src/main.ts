import { createApp } from 'vue';
import App from './App.vue';
import type { SeleneUiApi } from './selene';

export function mount(root: ParentNode, selene: SeleneUiApi): () => void {
  const target = root.querySelector('#illarion-ui');
  if (!(target instanceof HTMLElement)) throw new Error('Missing Illarion UI mount element.');

  const app = createApp(App, { selene });
  app.mount(target);
  return () => app.unmount();
}

if (import.meta.env.DEV && document.querySelector('#illarion-ui')) {
  mount(document, {
    apiVersion: 3,
    resolveAsset: path => new URL(path, window.location.href).href,
    visuals: {
      getDefinition: async identifier => {
        const response = await fetch(`/client/registries/selene:visuals`);
        const snapshot = await response.json() as { entries?: Record<string, import('./selene').VisualDefinition> };
        const definition = snapshot.entries?.[identifier];
        if (!definition) throw new Error(`Visual not found: ${identifier}`);
        return definition;
      },
    },
    storage: {
      load: async key => window.localStorage.getItem(`selene.bundle.dev.${key}`),
      save: async (key, value) => window.localStorage.setItem(`selene.bundle.dev.${key}`, value),
    },
    input: {
      captureKeys: () => () => undefined,
      captureText: () => () => undefined,
      passThroughKeys: () => () => undefined,
      onPointerDown: () => () => undefined,
      onPointerUp: () => () => undefined,
    },
    network: {
      sendToServer: (payloadId, payload) => console.info('[Selene UI]', payloadId, payload),
      onPayload: () => () => undefined,
    },
    world: {
      getCameraCoordinate: () => ({ x: 0, y: 0, z: 0 }),
      getMapTiles: () => [],
      onCameraCoordinateChanged: () => () => undefined,
      onMapChanged: () => () => undefined,
    },
  });
}

import { computed, readonly, ref, toValue, watchEffect, type MaybeRefOrGetter } from 'vue';
import { resolveClientAsset } from '../clientAssets';
import { useSelene } from '../selene';

export const useClientAssetSrc = (
  path: MaybeRefOrGetter<string>,
  fallbackPath?: MaybeRefOrGetter<string>,
) => {
  const selene = useSelene();
  const url = ref<string>();

  watchEffect((onCleanup) => {
    let active = true;
    onCleanup(() => { active = false; });
    void resolveClientAsset(selene, toValue(path))
      .catch((error: unknown) => {
        if (fallbackPath) return resolveClientAsset(selene, toValue(fallbackPath));
        throw error;
      })
      .then((value) => {
        if (active) url.value = value;
      })
      .catch((error) => console.warn(`[Client asset] ${path}`, error));
  });

  return readonly(url);
};

export const useUiAssetSrc = (fileName: MaybeRefOrGetter<string>) =>
  useClientAssetSrc(
    () => `client/textures/illarion/ui/${toValue(fileName)}`,
    () => `client/ui/dist/assets/${toValue(fileName)}`,
  );

export const useClientAssetStyle = (path: string) => {
  const url = useClientAssetSrc(path);
  return computed(() => (url.value ? `url("${url.value}")` : 'none'));
};

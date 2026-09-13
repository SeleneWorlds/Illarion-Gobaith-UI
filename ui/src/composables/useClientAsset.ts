import { computed, onMounted, readonly, ref } from 'vue';
import { resolveClientAsset } from '../clientAssets';
import { useSelene } from '../selene';

export const useClientAssetSrc = (path: string) => {
  const selene = useSelene();
  const url = ref<string>();

  onMounted(() => {
    void resolveClientAsset(selene, path)
      .then((value) => {
        url.value = value;
      })
      .catch((error) => console.warn(`[Client asset] ${path}`, error));
  });

  return readonly(url);
};

export const useClientAssetStyle = (path: string) => {
  const url = useClientAssetSrc(path);
  return computed(() => (url.value ? `url("${url.value}")` : 'none'));
};

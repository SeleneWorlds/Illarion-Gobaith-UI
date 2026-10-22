import { onMounted, onUnmounted } from 'vue';
import { useSelene } from '../selene';

export const onConnected = (callback: () => void): void => {
  const network = useSelene().network;
  let unsubscribe: () => void = () => undefined;

  onMounted(() => {
    unsubscribe = network.onConnected(callback);
  });
  onUnmounted(() => unsubscribe());
};

import { onBeforeUnmount, onMounted, watch, type Ref } from 'vue';
import { useSelene } from '../selene';

const closers = new Set<() => boolean>();
const onKeyDown = (event: KeyboardEvent) => {
  if (event.key !== 'Escape' || event.defaultPrevented) {
    return;
  }
  let closed = false;
  for (const close of closers) {
    closed = close() || closed;
  }
  if (closed) {
    event.preventDefault();
    event.stopImmediatePropagation();
  }
};

export const usePopupEscape = (isOpen: Ref<boolean>, close: () => void) => {
  const selene = useSelene();
  let releaseKeys: (() => void) | undefined;
  const closeIfOpen = () => {
    if (!isOpen.value) {
      return false;
    }
    close();
    return true;
  };
  watch(
    isOpen,
    (open) => {
      releaseKeys?.();
      releaseKeys = open ? selene.input.captureKeys('Escape') : undefined;
    },
    { immediate: true },
  );
  onMounted(() => {
    if (closers.size === 0) {
      window.addEventListener('keydown', onKeyDown);
    }
    closers.add(closeIfOpen);
  });
  onBeforeUnmount(() => {
    releaseKeys?.();
    closers.delete(closeIfOpen);
    if (closers.size === 0) {
      window.removeEventListener('keydown', onKeyDown);
    }
  });
};

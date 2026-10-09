import { inject, readonly, ref, type InjectionKey } from 'vue';
import type { ClientNetworkPayload, SeleneUiApi } from '../selene';

export const parseBookPage = (message: string) => {
  const match = /^#b\|([1-9]\d*)\|(\d+)\|([\s\S]*)$/.exec(message);
  if (!match) {
    return undefined;
  }
  const page = Number(match[1]);
  const itemId = Number(match[2]);
  if (!Number.isSafeInteger(page) || !Number.isSafeInteger(itemId)) {
    return undefined;
  }
  return { page, itemId, text: match[3] };
};

export const createBookStore = (network: SeleneUiApi['network']) => {
  const current = ref<ReturnType<typeof parseBookPage>>();
  const canNext = ref(true);
  let lastUse: { id: string; payload: ClientNetworkPayload } | undefined;
  let source: typeof lastUse;
  let requestExpiresAt = 0;
  const trackedNetwork: SeleneUiApi['network'] = {
    ...network,
    sendToServer(id, payload) {
      if (['illarion:use_slot', 'illarion:use_slot_at', 'illarion:use_at'].includes(id) && payload) {
        lastUse = { id, payload: { ...payload } };
      }
      network.sendToServer(id, payload);
    },
  };
  return {
    network: trackedNetwork,
    current: readonly(current),
    canNext: readonly(canNext),
    receive(message: string) {
      const page = parseBookPage(message);
      if (!page) {
        return false;
      }
      if (lastUse !== source) {
        source = lastUse;
        current.value = undefined;
      }
      // Duplicate replies do not indicate the end of a book. Requests past the
      // last page produce an ordinary inform message, with no book-page reply.
      canNext.value = page.page < 250;
      requestExpiresAt = 0;
      current.value = page;
      return true;
    },
    turn(delta: number) {
      if (!delta || !source || !current.value || Date.now() < requestExpiresAt || (delta > 0 && !canNext.value)) {
        return;
      }
      const page = current.value.page + delta;
      if (page < 1 || page > 250) {
        return;
      }
      // Wheel gestures can emit many events before the server answers. Keep
      // only one request in flight, but recover when the server sends no page.
      requestExpiresAt = Date.now() + 1000;
      network.sendToServer(source.id, { ...source.payload, count: page });
    },
    close() {
      current.value = undefined;
      requestExpiresAt = 0;
    },
  };
};
export type BookStore = ReturnType<typeof createBookStore>;
export const bookStoreKey: InjectionKey<BookStore> = Symbol('book-store');
export const useBookStore = () => {
  const store = inject(bookStoreKey);
  if (!store) {
    throw new Error('Book store was not provided.');
  }
  return store;
};

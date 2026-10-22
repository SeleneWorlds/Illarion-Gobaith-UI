import { inject, ref, type InjectionKey } from 'vue';

export interface AdminRequestTarget {
  name: string;
  characterId: number;
}

export const createAdminRequestStore = () => {
  const isOpen = ref(false);
  const target = ref<AdminRequestTarget>();
  return {
    isOpen,
    target,
    open(character?: AdminRequestTarget) {
      target.value = character;
      isOpen.value = true;
    },
    close() {
      isOpen.value = false;
      target.value = undefined;
    },
  };
};

export type AdminRequestStore = ReturnType<typeof createAdminRequestStore>;
export const adminRequestStoreKey: InjectionKey<AdminRequestStore> = Symbol('admin-request-store');
export const useAdminRequestStore = () => {
  const store = inject(adminRequestStoreKey);
  if (!store) {
    throw new Error('Admin request store was not provided.');
  }
  return store;
};

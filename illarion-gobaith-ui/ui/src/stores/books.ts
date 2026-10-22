import { inject, type InjectionKey } from 'vue';
import type { BookService } from 'illarion-client-core';

export const bookStoreKey: InjectionKey<BookService> = Symbol('book-store');
export const useBookStore = (): BookService => {
  const store = inject(bookStoreKey);
  if (!store) {
    throw new Error('Book store was not provided.');
  }
  return store;
};

import { computed, readonly, ref } from 'vue';
import { z } from 'zod';
import type { SeleneUiApi } from './selene';

const bookPageSchema = z
  .object({
    id: z.number().int().positive().safe(),
    page: z.number().int().positive().safe(),
    pageCount: z.number().int().positive().safe(),
    itemId: z.number().int().nonnegative().safe(),
    text: z.string(),
  })
  .refine((page) => page.page <= page.pageCount);
export type BookPage = z.infer<typeof bookPageSchema>;

export const createBookService = (network: SeleneUiApi['network']) => {
  const current = ref<BookPage>();
  let latestId = 0;
  let closedId = 0;
  let requestExpiresAt = 0;
  network.onPayload('illarion:book_page', (payload) => {
    const result = bookPageSchema.safeParse(payload);
    if (!result.success || result.data.id < latestId || result.data.id === closedId) {
      return;
    }
    latestId = result.data.id;
    current.value = result.data;
    requestExpiresAt = 0;
  });
  network.onConnected(() => {
    current.value = undefined;
    latestId = 0;
    closedId = 0;
    requestExpiresAt = 0;
  });
  return {
    current: readonly(current),
    canNext: computed(() => Boolean(current.value && current.value.page < current.value.pageCount)),
    turn(delta: number) {
      const book = current.value;
      if (!book || !Number.isInteger(delta) || !delta || Date.now() < requestExpiresAt) {
        return;
      }
      const page = book.page + delta;
      if (page < 1 || page > book.pageCount) {
        return;
      }
      requestExpiresAt = Date.now() + 1000;
      network.sendToServer('illarion:book_request_page', { id: book.id, page });
    },
    close() {
      if (current.value) {
        closedId = current.value.id;
        network.sendToServer('illarion:book_close', { id: closedId });
      }
      current.value = undefined;
      requestExpiresAt = 0;
    },
  };
};
export type BookService = ReturnType<typeof createBookService>;

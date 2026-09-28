import { inject, readonly, ref, type InjectionKey, type Ref } from 'vue';
import { z } from 'zod';
import type { LogMessage } from '../composables/useLogger';
import { usePayload } from '../composables/usePayload';

const informPayloadSchema = z.object({
  Message: z.string().min(1),
});
const chatModeSchema = z
  .union([z.literal(0), z.literal(1), z.literal(2), z.literal('ooc'), z.literal('emote')])
  .transform((mode) => {
    if (mode === 0) {
      return 'normal';
    }
    if (mode === 1) {
      return 'whisper';
    }
    if (mode === 2) {
      return 'shout';
    }
    return mode;
  });
const chatPayloadSchema = z.object({
  authorName: z.string().optional().default(''),
  message: z.string().min(1),
  mode: chatModeSchema,
  showInChat: z.boolean().optional(),
});

export interface ChatMessage extends LogMessage {
  id: number;
}

export interface ChatStore {
  readonly messages: Readonly<Ref<readonly ChatMessage[]>>;
}

export const chatStoreKey: InjectionKey<ChatStore> = Symbol('chat-store');

export const createChatStore = (log: (message: LogMessage) => void): ChatStore => {
  const messages = ref<ChatMessage[]>([]);
  let nextMessageId = 0;

  const addMessage = (text: string, kind: string, author = '', shouldLog = false) => {
    const entry = { id: nextMessageId++, author, text, kind };
    messages.value.push(entry);
    if (shouldLog) {
      log(entry);
    }
    const excess = messages.value.length - 100;
    if (excess > 0) {
      messages.value.splice(0, excess);
    }
  };

  usePayload('illarion:inform', informPayloadSchema, (payload) => {
    addMessage(payload.Message, 'inform');
  });
  usePayload('illarion:chat', chatPayloadSchema, (payload) => {
    if (payload.showInChat !== false) {
      addMessage(payload.message, payload.mode, payload.authorName, true);
    }
  });

  return { messages: readonly(messages) };
};

export const useChatStore = (): ChatStore => {
  const store = inject(chatStoreKey);
  if (!store) {
    throw new Error('Chat store was not provided.');
  }
  return store;
};

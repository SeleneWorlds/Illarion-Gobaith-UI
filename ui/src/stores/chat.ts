import { inject, readonly, ref, type InjectionKey, type Ref } from 'vue';
import { z } from 'zod';
import type { LogMessage } from '../composables/useLogger';
import { usePayload } from '../composables/usePayload';
import { onConnected } from '../composables/onConnected';

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
  author: z.number().int().safe().optional(),
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
  readonly bubbles: Readonly<Ref<readonly ChatBubble[]>>;
  expireBubbles(now: number): void;
}

export interface ChatBubble {
  id: number;
  author: number;
  text: string;
  kind: string;
  createdAt: number;
  expiresAt: number;
}

export const chatStoreKey: InjectionKey<ChatStore> = Symbol('chat-store');

export const createChatStore = (
  log: (message: LogMessage) => void,
  receiveBook: (message: string) => boolean,
): ChatStore => {
  const messages = ref<ChatMessage[]>([]);
  const bubbles = ref<ChatBubble[]>([]);
  let nextMessageId = 0;
  let nextBubbleId = 0;
  onConnected(() => {
    bubbles.value = [];
  });

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
    if (!receiveBook(payload.Message)) {
      addMessage(payload.Message, 'inform');
    }
  });
  usePayload('illarion:chat', chatPayloadSchema, (payload) => {
    if (payload.author !== undefined && payload.message.trim()) {
      const now = performance.now();
      const text = payload.mode === 'emote' ? `${payload.authorName} ${payload.message}`.trim() : payload.message;
      bubbles.value.push({
        id: nextBubbleId++,
        author: payload.author,
        text,
        kind: payload.mode,
        createdAt: now,
        expiresAt: now + 2500 + (5000 * text.length) / 80,
      });
      if (bubbles.value.length > 100) {
        bubbles.value.splice(0, bubbles.value.length - 100);
      }
    }
    if (payload.showInChat !== false) {
      addMessage(payload.message, payload.mode, payload.authorName, true);
    }
  });

  return {
    messages: readonly(messages),
    bubbles: readonly(bubbles),
    expireBubbles(now) {
      if (bubbles.value.some((bubble) => bubble.expiresAt + 200 <= now)) {
        bubbles.value = bubbles.value.filter((bubble) => bubble.expiresAt + 200 > now);
      }
    },
  };
};

export const useChatStore = (): ChatStore => {
  const store = inject(chatStoreKey);
  if (!store) {
    throw new Error('Chat store was not provided.');
  }
  return store;
};

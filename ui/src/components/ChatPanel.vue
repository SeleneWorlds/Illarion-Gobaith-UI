<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue';
import type { ClientNetworkPayload, SeleneUiApi } from '../selene';

const props = defineProps<{ selene: SeleneUiApi }>();
const CHAT_PAYLOAD = 'illarion:chat';
const INFORM_PAYLOAD = 'illarion:inform';
const MAX_MESSAGES = 200;
const GAME_PASSTHROUGH_KEYS = new Set(['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight']);
const modes = [
  { id: 'normal', name: 'Normal', icon: 'speak_normal.png', payloadMode: 'normal' },
  { id: 'whisper', name: 'Whisper', icon: 'speak_whisper.png', payloadMode: 'whisper' },
  { id: 'shout', name: 'Shout', icon: 'speak_shout.png', payloadMode: 'yell' },
  { id: 'ooc', name: 'OOC', icon: 'speak_ooc.png', payloadMode: 'normal', prefix: '#o ' },
] as const;
type MessageKind = 'notice' | 'emote' | (typeof modes)[number]['id'];
interface ChatMessage { id: number; author: string; text: string; kind: MessageKind }

const history = ref<HTMLElement>();
const input = ref<HTMLTextAreaElement>();
const message = ref('');
const modeIndex = ref(0);
const messages = ref<ChatMessage[]>([]);
let nextMessageId = 0;
const unsubscribers: Array<() => void> = [];

const mode = () => modes[modeIndex.value];
const resizeInput = async () => {
  await nextTick();
  if (!input.value || !history.value) return;
  input.value.style.height = '20px';
  input.value.style.height = `${Math.min(64, Math.max(20, input.value.scrollHeight))}px`;
  history.value.style.bottom = `${Math.min(76, input.value.offsetHeight + 12)}px`;
};
const addMessage = async (text: unknown, kind: MessageKind, author = '') => {
  if (typeof text !== 'string' || text.length === 0) return;
  const wasAtBottom = !history.value || history.value.scrollHeight - history.value.scrollTop - history.value.clientHeight < 8;
  messages.value.push({ id: nextMessageId++, author, text, kind });
  if (messages.value.length > MAX_MESSAGES) messages.value.shift();
  await nextTick();
  if (wasAtBottom && history.value) history.value.scrollTop = history.value.scrollHeight;
};
const normalizeMode = (value: unknown): MessageKind => {
  if (value === 1 || value === 'whisper') return 'whisper';
  if (value === 2 || value === 'yell' || value === 'shout') return 'shout';
  if (value === 'ooc') return 'ooc';
  if (value === 'emote') return 'emote';
  return 'normal';
};
const send = () => {
  const text = message.value.trim();
  if (!text) return;
  const currentMode = mode();
  const prefix = 'prefix' in currentMode ? currentMode.prefix : '';
  props.selene.network.sendToServer(CHAT_PAYLOAD, {
    mode: currentMode.payloadMode,
    message: `${prefix}${text}`,
  });
  message.value = '';
  void resizeInput();
};
const cycleMode = () => {
  modeIndex.value = (modeIndex.value + 1) % modes.length;
  input.value?.focus();
};
const onInputKeydown = (event: KeyboardEvent) => {
  if (GAME_PASSTHROUGH_KEYS.has(event.key)) return event.preventDefault();
  event.stopPropagation();
  if (event.key === 'Enter' && !event.shiftKey) {
    event.preventDefault();
    send();
  } else if (event.key === 'Escape') {
    event.preventDefault();
    input.value?.blur();
  }
};
const onInputKeyup = (event: KeyboardEvent) => {
  if (!GAME_PASSTHROUGH_KEYS.has(event.key)) event.stopPropagation();
};
const isEditable = (element: Element | null): boolean => (
  element instanceof HTMLInputElement
  || element instanceof HTMLTextAreaElement
  || (element instanceof HTMLElement && element.isContentEditable)
);
const onWindowKeydown = (event: KeyboardEvent) => {
  const root = input.value?.getRootNode();
  const activeElement = root instanceof Document || root instanceof ShadowRoot ? root.activeElement : null;
  if (event.defaultPrevented || isEditable(activeElement) || isEditable(event.target as Element | null)) return;
  if (event.key === 'Enter') send();
  else if (event.key === 'Backspace') message.value = message.value.slice(0, -1);
  else if (event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey) message.value += event.key;
  else return;
  event.preventDefault();
  event.stopPropagation();
  void resizeInput();
};
const stringValue = (payload: ClientNetworkPayload, key: string) => typeof payload[key] === 'string' ? payload[key] : '';

onMounted(() => {
  window.addEventListener('keydown', onWindowKeydown, true);
  unsubscribers.push(props.selene.input.captureKeys('Enter', 'Backspace'));
  unsubscribers.push(props.selene.input.captureText());
  unsubscribers.push(props.selene.input.passThroughKeys(...GAME_PASSTHROUGH_KEYS));
  unsubscribers.push(props.selene.network.onPayload(INFORM_PAYLOAD, payload => void addMessage(payload.Message, 'notice')));
  unsubscribers.push(props.selene.network.onPayload(CHAT_PAYLOAD, payload => {
    if (payload.showInChat === false) return;
    const author = stringValue(payload, 'authorName');
    const text = stringValue(payload, 'message');
    if (author || text) void addMessage(text, normalizeMode(payload.mode), author);
  }));
  void resizeInput();
});
onBeforeUnmount(() => {
  window.removeEventListener('keydown', onWindowKeydown, true);
  unsubscribers.forEach(unsubscribe => unsubscribe());
});
</script>

<template>
  <section class="chat" aria-label="Chat" data-selene-interactive>
    <div ref="history" class="chat__history" role="log" aria-live="polite" aria-relevant="additions">
      <p v-for="item in messages" :key="item.id" :class="item.kind === 'notice' ? 'chat__notice' : `chat__message chat__message--${item.kind}`">
        <strong v-if="item.author">{{ item.author }}{{ item.kind === 'emote' ? ' ' : ': ' }}</strong>{{ item.text }}
      </p>
    </div>
    <label class="visually-hidden" for="chat-input">Chat message</label>
    <textarea id="chat-input" ref="input" v-model="message" class="chat__input" rows="1" maxlength="4096" autocomplete="off" spellcheck="true" aria-label="Chat message" @input="resizeInput" @keydown="onInputKeydown" @keyup="onInputKeyup" />
  </section>
  <button class="chat__mode" type="button" data-selene-interactive :data-mode="mode().id" :aria-label="`Speech mode: ${mode().name}`" :title="`${mode().name} — click to change speech mode`" @click="cycleMode">
    <img :src="selene.resolveAsset(`./assets/${mode().icon}`)" alt="">
  </button>
</template>

<style scoped>
.visually-hidden { position: absolute; width: 1px; height: 1px; padding: 0; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }

.chat {
  position: absolute;
  left: 0;
  bottom: 140px;
  width: 784px;
  height: 228px;
  overflow: hidden;
  padding: 12px 18px 10px 12px;
  color: #fff;
  text-shadow: 1px 1px 2px #000, 0 0 3px #000;
  pointer-events: auto;
}

.chat::before { position: absolute; inset: 0; background: rgb(0 0 0 / 42%); content: ""; }
.chat__history { position: absolute; top: 8px; right: 18px; bottom: 32px; left: 12px; overflow: hidden auto; scrollbar-width: thin; scrollbar-color: rgb(210 220 225 / 35%) transparent; }
.chat p { margin: 2px 0; line-height: 1.25; }
.chat__notice { color: #B2CCFF; }
.chat__message--whisper, .chat__message--ooc { color: #999999; }
.chat__message--shout { color: #FF4C4C; }
.chat__message--emote { color: #FFFF33; }
.chat__input { position: absolute; right: 18px; bottom: 8px; left: 12px; height: 20px; min-height: 20px; max-height: 64px; margin: 0; padding: 1px 3px; resize: none; overflow: hidden; border: 0; outline: 0; background: transparent; color: #fff; line-height: 17px; text-shadow: inherit; }
.chat__mode { position: absolute; left: 799px; bottom: 146px; width: 30px; height: 30px; padding: 0; overflow: hidden; border: 0; background: transparent; cursor: pointer; pointer-events: auto; }
.chat__mode img { display: block; width: 30px; height: 30px; }
.chat__mode:focus-visible { outline: 1px solid #b7d9ba; outline-offset: 1px; }
</style>

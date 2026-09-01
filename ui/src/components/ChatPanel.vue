<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref } from 'vue';
import type { ClientNetworkPayload, SeleneUiApi } from '../selene';
import ContextMenu from './ContextMenu.vue';

const props = defineProps<{ selene: SeleneUiApi }>();
const CHAT_PAYLOAD = 'illarion:chat';
const INFORM_PAYLOAD = 'illarion:inform';
const MAX_INPUT_LENGTH = 200;
const MAX_RENDERED_HISTORY_HEIGHT = 550;
const LOG_STORAGE_KEY = 'illarion.log';
const GAME_PASSTHROUGH_KEYS = new Set(['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight']);
const modes = [
  { id: 'normal', name: 'Normal', icon: 'speak_normal.png', payloadMode: 'normal' },
  { id: 'whisper', name: 'Whisper', icon: 'speak_whisper.png', payloadMode: 'whisper' },
  { id: 'shout', name: 'Shout', icon: 'speak_shout.png', payloadMode: 'yell' },
  { id: 'ooc', name: 'OOC', icon: 'speak_ooc.png', payloadMode: 'normal', prefix: '#o ' },
] as const;
const languages = ['Common', 'Ancient', 'Halfling', 'Dwarf', 'Elf', 'Human', 'Lizard', 'Orc', 'Fairy', 'Gnoll', 'Goblin'] as const;
type MessageKind = 'notice' | 'emote' | (typeof modes)[number]['id'];
interface ChatMessage { id: number; author: string; text: string; kind: MessageKind }

const history = ref<HTMLElement>();
const historyContent = ref<HTMLElement>();
const input = ref<HTMLTextAreaElement>();
const message = ref('');
const modeIndex = ref(0);
const menuOpen = ref(false);
const expanded = ref(false);
const messages = ref<ChatMessage[]>([]);
let nextMessageId = 0;
let logWrite = Promise.resolve();
const unsubscribers: Array<() => void> = [];

const mode = () => modes[modeIndex.value];
const renderedText = ({ author, text, kind }: ChatMessage) => author
  ? `${author}${kind === 'emote' ? ' ' : ': '}${text}`
  : text;
const appendLog = (entry: ChatMessage) => {
  const prefix = entry.kind === 'shout' ? 'S:' : entry.kind === 'whisper' ? 'w:' : '';
  const line = `${prefix}${renderedText(entry)}\n`;
  logWrite = logWrite
    .then(async () => props.selene.storage.save(LOG_STORAGE_KEY, `${await props.selene.storage.load(LOG_STORAGE_KEY) ?? ''}${line}`))
    .catch(error => console.warn('Could not write illarion.log.', error));
};
const trimHistory = async () => {
  await nextTick();
  while (messages.value.length > 1 && (historyContent.value?.scrollHeight ?? 0) > MAX_RENDERED_HISTORY_HEIGHT) {
    messages.value.shift();
    await nextTick();
  }
};
const resizeInput = async () => {
  await nextTick();
  if (!input.value || !history.value) return;
  input.value.style.height = '20px';
  input.value.style.height = `${Math.min(64, Math.max(20, input.value.scrollHeight))}px`;
  history.value.style.bottom = `${Math.min(76, input.value.offsetHeight + 12)}px`;
};
const addMessage = async (text: unknown, kind: MessageKind, author = '', log = false) => {
  if (typeof text !== 'string' || text.length === 0) return;
  const entry = { id: nextMessageId++, author, text, kind };
  messages.value.push(entry);
  if (log) appendLog(entry);
  await trimHistory();
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
  menuOpen.value = false;
  modeIndex.value = (modeIndex.value + 1) % modes.length;
  input.value?.focus();
};
const openMenu = () => { menuOpen.value = true; };
const closeMenu = () => { menuOpen.value = false; };
const selectMode = (index: number) => {
  modeIndex.value = index;
  closeMenu();
  input.value?.focus();
};
const selectLanguage = (language: string) => {
  props.selene.network.sendToServer(CHAT_PAYLOAD, { mode: 'normal', message: `!l ${language.toLowerCase()}` });
  closeMenu();
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
  else if (event.key.length === 1 && !event.ctrlKey && !event.metaKey && !event.altKey && message.value.length < MAX_INPUT_LENGTH) message.value += event.key;
  else return;
  event.preventDefault();
  event.stopPropagation();
  void resizeInput();
};
const onWheel = (event: WheelEvent) => {
  if (event.deltaY === 0) return;
  expanded.value = event.deltaY < 0;
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
    if (author || text) void addMessage(text, normalizeMode(payload.mode), author, true);
  }));
  void resizeInput();
});
onBeforeUnmount(() => {
  window.removeEventListener('keydown', onWindowKeydown, true);
  unsubscribers.forEach(unsubscribe => unsubscribe());
});
</script>

<template>
  <section class="chat" :class="{ 'chat--expanded': expanded }" :style="{ '--chat-background': `url(${selene.resolveAsset('./assets/gui_chat.png')})` }" aria-label="Chat" data-selene-interactive @wheel.prevent.stop="onWheel">
    <div ref="history" class="chat__history" role="log" aria-live="polite" aria-relevant="additions">
      <div ref="historyContent" class="chat__history-content">
        <TransitionGroup name="chat-line">
          <p v-for="item in messages" :key="item.id" :class="item.kind === 'notice' ? 'chat__notice' : `chat__message chat__message--${item.kind}`">
            <strong v-if="item.author">{{ item.author }}{{ item.kind === 'emote' ? ' ' : ': ' }}</strong>{{ item.text }}
          </p>
        </TransitionGroup>
      </div>
    </div>
    <label class="visually-hidden" for="chat-input">Chat message</label>
    <textarea id="chat-input" ref="input" v-model="message" class="chat__input" rows="1" :maxlength="MAX_INPUT_LENGTH" autocomplete="off" spellcheck="true" aria-label="Chat message" @input="resizeInput" @keydown="onInputKeydown" @keyup="onInputKeyup" />
  </section>
  <button class="chat__mode" type="button" data-selene-interactive :data-mode="mode().id" :aria-label="`Speech mode: ${mode().name}`" aria-haspopup="menu" :aria-expanded="menuOpen" :title="`${mode().name} — click to change speech mode; right-click for menu`" @click.stop="cycleMode" @contextmenu.prevent.stop="openMenu">
    <img :src="selene.resolveAsset(`./assets/${mode().icon}`)" alt="">
  </button>
  <ContextMenu class="speech-menu" :open="menuOpen" variant="long" :frame-src="selene.resolveAsset('./assets/menu_long.png')" label="Speech options" @close="closeMenu">
    <li v-for="(item, index) in modes" v-show="index !== modeIndex" :key="item.id">
      <button type="button" @click="selectMode(index)">{{ item.name === 'Normal' ? 'Speak' : item.name }}</button>
    </li>
    <li class="context-menu__separator" role="separator" />
    <li v-for="language in languages" :key="language">
      <button type="button" @click="selectLanguage(language)">{{ language }}</button>
    </li>
  </ContextMenu>
</template>

<style scoped>
.visually-hidden { position: absolute; width: 1px; height: 1px; padding: 0; overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0; }

.chat {
  position: absolute;
  left: 0;
  bottom: 141px;
  width: 784px;
  height: 212px;
  overflow: hidden;
  padding: 12px 18px 10px 12px;
  color: #fff;
  text-shadow: 1px 1px 2px #000, 0 0 3px #000;
  pointer-events: auto;
  transition: height 180ms ease-out;
}

.chat--expanded { height: 590px; }
.chat::before { position: absolute; inset: 0; background: var(--chat-background) 0 100% / 100% 100% no-repeat; content: ""; transition: opacity 180ms ease-out; }
.chat--expanded::before { opacity: .75; }
.chat__history { position: absolute; top: 8px; right: 18px; bottom: 32px; left: 12px; overflow: hidden; }
.chat__history-content { position: absolute; right: 0; bottom: 0; left: 0; }
.chat p { margin: 2px 0; line-height: 1.25; }
.chat-line-enter-active { transition: opacity 140ms ease-out, transform 140ms ease-out; }
.chat-line-enter-from { opacity: 0; transform: translateY(16px); }
.chat__notice { color: #B2CCFF; }
.chat__message--whisper, .chat__message--ooc { color: #999999; }
.chat__message--shout { color: #FF4C4C; }
.chat__message--emote { color: #FFFF33; }
.chat__input { position: absolute; right: 18px; bottom: 8px; left: 12px; height: 20px; min-height: 20px; max-height: 64px; margin: 0; padding: 1px 3px; resize: none; overflow: hidden; border: 0; outline: 0; background: transparent; color: #fff; line-height: 17px; text-shadow: inherit; }
.chat__mode { position: absolute; left: 799px; bottom: 146px; width: 30px; height: 30px; padding: 0; overflow: hidden; border: 0; background: transparent; cursor: pointer; pointer-events: auto; }
.chat__mode img { display: block; width: 30px; height: 30px; }
.chat__mode:focus-visible { outline: 1px solid #b7d9ba; outline-offset: 1px; }
.speech-menu { left: 770px; bottom: 178px; }
</style>
